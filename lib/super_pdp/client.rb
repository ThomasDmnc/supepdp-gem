# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module SuperPDP
  # Thin HTTP client for the SUPER PDP API.
  #
  # Auth: pass an +access_token+ directly (e.g. one you obtained via the
  # authorization_code flow to act on a user's behalf), or pass
  # +client_id+/+client_secret+ to have the client fetch and refresh a
  # client_credentials token automatically (acts on your own data, api-key-like).
  class Client
    DEFAULT_BASE_URL = "https://api.superpdp.tech"
    API_PREFIX = "/v1.beta"
    USER_AGENT = "super_pdp/#{VERSION} (Ruby #{RUBY_VERSION})".freeze

    # Transient failures retried automatically (idempotent verbs only).
    RETRYABLE_STATUSES = [429, 502, 503, 504].freeze
    RETRYABLE_METHODS = %i[get delete].freeze
    RETRYABLE_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET,
                        Errno::ECONNREFUSED, IOError].freeze

    attr_reader :base_url

    def initialize(access_token: nil, client_id: nil, client_secret: nil,
                   base_url: DEFAULT_BASE_URL, open_timeout: 10, read_timeout: 60,
                   max_retries: 2, retry_base: 0.5)
      @access_token = access_token
      @client_id = client_id
      @client_secret = client_secret
      @base_url = base_url
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @max_retries = max_retries
      @retry_base = retry_base
      @token_expires_at = nil
      @token_mutex = Mutex.new

      return if access_token || (client_id && client_secret)

      raise ArgumentError, "provide access_token, or client_id and client_secret"
    end

    # --- Resource helpers (thin wrappers over the raw verbs) --------------

    def companies_me(**params) = get("/companies/me", params)
    def enroll_company(body) = post("/companies", body)
    def update_company_vat_regime(body) = patch("/companies", body)

    def invoices(**params) = get("/invoices", params)
    def invoice(id, **params) = get("/invoices/#{id}", params)
    def create_invoice(body, **params) = post("/invoices", body, params)
    def convert_invoice(body, **params) = post("/invoices/convert", body, params)
    def validation_report(body) = post("/validation_reports", body)
    def generate_test_invoice(**params) = get("/invoices/generate_test_invoice", params)

    # Raw invoice file bytes (not JSON) — returns the String body.
    def download_invoice(id, **params) = request(:get, "/invoices/#{id}/download", query: params, raw: true)

    def invoice_events(**params) = get("/invoice_events", params)
    def create_invoice_event(body) = post("/invoice_events", body)

    def ereportings(**params) = get("/ereportings", params)
    def ereporting(id, **params) = get("/ereportings/#{id}", params)
    def preview_ereporting(**params) = get("/ereportings/preview", params)

    def b2c_transactions(**params) = get("/b2c_transactions", params)
    def create_b2c_transactions(body) = post("/b2c_transactions", body)
    def b2c_payments(**params) = get("/b2c_payments", params)
    def create_b2c_payment(body) = post("/b2c_payments", body)

    def directory_entries(**params) = get("/directory_entries", params)
    def directory_entry(id, **params) = get("/directory_entries/#{id}", params)
    def create_directory_entry(body) = post("/directory_entries", body)
    def delete_directory_entry(id) = delete("/directory_entries/#{id}")

    def french_directory_companies(**params) = get("/french_directory/companies", params)
    def french_directory_entries(**params) = get("/french_directory/entries", params)

    def oauth2_session_me(**params) = get("/oauth2_sessions/me", params)

    # Iterate a list endpoint across all pages, yielding each item.
    # Uses the API's cursor pagination (starting_after_id + has_after).
    # Returns an Enumerator when no block is given.
    def each_item(path, **params, &block)
      return enum_for(:each_item, path, **params) unless block_given?

      cursor = params[:starting_after_id]
      loop do
        page = get(path, params.merge(starting_after_id: cursor).compact)
        data = page["data"] || []
        data.each(&block)
        break unless page["has_after"] && !data.empty?

        cursor = data.last["id"]
      end
    end

    # --- Raw verbs --------------------------------------------------------

    def get(path, query = {}) = request(:get, path, query: query)
    def post(path, body = {}, query = {}) = request(:post, path, body: body, query: query)
    def patch(path, body = {}, query = {}) = request(:patch, path, body: body, query: query)
    def delete(path, query = {}) = request(:delete, path, query: query)

    # Retries transient failures (429 + 502/503/504 + connection errors) with
    # backoff for idempotent verbs only. See RETRYABLE_* constants.
    def request(method, path, query: {}, body: nil, raw: false)
      uri = build_uri(path, query)
      attempt = 0
      loop do
        attempt += 1
        res =
          begin
            perform(method, uri, body)
          rescue *RETRYABLE_ERRORS
            raise unless retryable?(method, attempt)

            sleep backoff(attempt)
            next
          end
        return handle_response(res, raw: raw) unless retry_status?(method, res.code.to_i, attempt)

        sleep(retry_after(res) || backoff(attempt))
      end
    end

    private

    def perform(method, uri, body)
      req = build_request(method, uri, body)
      req["Authorization"] = "Bearer #{token}"
      http(uri).request(req)
    end

    def retryable?(method, attempt) = RETRYABLE_METHODS.include?(method) && attempt <= @max_retries
    def retry_status?(method, status, attempt) = retryable?(method, attempt) && RETRYABLE_STATUSES.include?(status)
    def backoff(attempt) = @retry_base * (2**(attempt - 1))

    def retry_after(res)
      v = res["Retry-After"]
      v =~ /\A\d+\z/ ? Integer(v) : nil # honor integer seconds; ignore HTTP-date form
    end

    def build_uri(path, query)
      full = path.start_with?("/v1") || path.start_with?("http") ? path : "#{API_PREFIX}#{path}"
      uri = URI.join(@base_url, full)
      q = flatten_query(query || {})
      uri.query = URI.encode_www_form(q) unless q.empty?
      uri
    end

    # Encode array params as repeated `key[]=v` pairs (matches expand[] etc).
    def flatten_query(query)
      query.compact.flat_map do |k, v|
        v.is_a?(Array) ? v.map { |item| ["#{k}[]", item] } : [[k.to_s, v]]
      end
    end

    def build_request(method, uri, body)
      klass = {
        get: Net::HTTP::Get, post: Net::HTTP::Post,
        patch: Net::HTTP::Patch, delete: Net::HTTP::Delete
      }.fetch(method)
      req = klass.new(uri)
      req["Accept"] = "application/json"
      req["User-Agent"] = USER_AGENT
      if body
        req["Content-Type"] = "application/json"
        req.body = body.is_a?(String) ? body : JSON.generate(body)
      end
      req
    end

    def http(uri)
      Net::HTTP.new(uri.host, uri.port).tap do |h|
        h.use_ssl = uri.scheme == "https"
        h.open_timeout = @open_timeout
        h.read_timeout = @read_timeout
      end
    end

    def handle_response(res, raw:)
      status = res.code.to_i
      body = raw ? res.body : parse_json(res.body)
      return body if status.between?(200, 299)

      raise APIError.new(status, body)
    end

    def parse_json(str)
      return nil if str.nil? || str.empty?

      JSON.parse(str)
    rescue JSON::ParserError
      str
    end

    # --- OAuth2 -----------------------------------------------------------

    def token
      # Lock so a shared client in a threaded server (Puma/Sidekiq) doesn't
      # race two concurrent refreshes. Double-checked inside the lock.
      @token_mutex.synchronize do
        return @access_token if @access_token && !expired?

        fetch_client_credentials_token
      end
    end

    def expired?
      @token_expires_at && Time.now >= @token_expires_at
    end

    def fetch_client_credentials_token
      unless @client_id && @client_secret
        raise AuthError, "access_token missing/expired and no client credentials to refresh it"
      end

      uri = URI.join(@base_url, "/oauth2/token")
      req = Net::HTTP::Post.new(uri)
      req["Accept"] = "application/json"
      req["User-Agent"] = USER_AGENT
      req.set_form_data(
        grant_type: "client_credentials",
        client_id: @client_id,
        client_secret: @client_secret
      )
      res = http(uri).request(req)
      raise AuthError, "token request failed (#{res.code}): #{res.body}" unless res.code.to_i.between?(200, 299)

      data = JSON.parse(res.body)
      @access_token = data.fetch("access_token")
      # Refresh 60s early. Default to 1h if the server omits expires_in.
      @token_expires_at = Time.now + (data["expires_in"] || 3600).to_i - 60
      @access_token
    end
  end
end
