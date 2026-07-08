# frozen_string_literal: true

require "minitest/autorun"
require "socket"
require_relative "../lib/super_pdp"

# Minimal stdlib TCP server so we exercise the real Net::HTTP path:
# token fetch, Bearer auth, array-query encoding, pagination, error mapping.
class SuperPDPTest < Minitest::Test
  def setup
    @requests = []
    @token_expires_in = 3600
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @base = "http://127.0.0.1:#{@port}"
    @thread = Thread.new { serve_loop }
  end

  def teardown
    @stop = true
    @server.close
    @thread.join
  end

  def serve_loop
    loop do
      conn = @server.accept
      handle(conn)
    rescue IOError, Errno::EBADF
      break
    end
  end

  # Parse just enough HTTP/1.1: request line + headers, drain a declared body.
  def handle(conn)
    request_line = conn.gets or return conn.close
    method, target, = request_line.split
    headers = {}
    while (line = conn.gets) && line != "\r\n"
      k, v = line.split(":", 2)
      headers[k.downcase] = v.to_s.strip
    end
    length = headers["content-length"].to_i
    body = length.positive? ? conn.read(length) : nil

    path, query = target.split("?", 2)
    @requests << { method: method, path: path, query: query.to_s, headers: headers, body: body }
    conn.write(response_for(path, query.to_s))
    conn.close
  end

  def response_for(path, query)
    body =
      case path
      when "/oauth2/token"
        JSON.generate(access_token: "tok-123", expires_in: @token_expires_in)
      when "/v1.beta/companies/me"
        JSON.generate(id: 1, name: "ACME")
      when "/v1.beta/invoices/42/download"
        return http("200 OK", "%PDF-1.4 rawbytes", "application/pdf")
      when "/v1.beta/plain"
        return http("200 OK", "not json at all", "text/plain")
      when "/v1.beta/invoices"
        if query.include?("starting_after_id")
          JSON.generate(data: [{ id: 3 }], count: 1, has_after: false, has_before: true)
        else
          JSON.generate(data: [{ id: 1 }, { id: 2 }], count: 2, has_after: true, has_before: false)
        end
      when "/v1.beta/boom"
        return http("422 Unprocessable Entity", JSON.generate(message: "nope"))
      when "/v1.beta/flaky"
        @flaky_hits = @flaky_hits.to_i + 1
        return http("503 Service Unavailable", JSON.generate(message: "later")) if @flaky_hits < 3

        JSON.generate(ok: true)
      when "/v1.beta/always_503"
        return http("503 Service Unavailable", JSON.generate(message: "down"))
      when "/v1.beta/rate_limited"
        @rl_hits = @rl_hits.to_i + 1
        if @rl_hits < 2
          return http("429 Too Many Requests", JSON.generate(message: "slow down"),
                      headers: { "Retry-After" => "0" })
        end

        JSON.generate(ok: true)
      else
        "{}"
      end
    http("200 OK", body)
  end

  def http(status, body, content_type = "application/json", headers: {})
    extra = headers.map { |k, v| "#{k}: #{v}\r\n" }.join
    "HTTP/1.1 #{status}\r\nContent-Type: #{content_type}\r\n#{extra}" \
      "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
  end

  def client(**opts) = SuperPDP.new(base_url: @base, **opts)
  def paths = @requests.map { |r| r[:path] }

  def test_requires_credentials
    assert_raises(ArgumentError) { SuperPDP.new }
  end

  def test_client_credentials_token_then_authorized_call
    me = client(client_id: "cid", client_secret: "sec").companies_me

    assert_equal "ACME", me["name"]
    assert_includes paths, "/oauth2/token"
  end

  def test_static_access_token_skips_token_endpoint
    client(access_token: "tok-123").companies_me

    refute_includes paths, "/oauth2/token"
  end

  def test_expired_token_is_refreshed
    @token_expires_in = 0 # server-issued token is already past its refresh margin
    pdp = client(client_id: "cid", client_secret: "sec")
    pdp.companies_me
    pdp.companies_me

    assert_equal 2, paths.count("/oauth2/token")
  end

  def test_expired_static_token_without_creds_raises_auth_error
    pdp = client(access_token: "tok-123")
    pdp.instance_variable_set(:@token_expires_at, Time.now - 1) # force expiry
    assert_raises(SuperPDP::AuthError) { pdp.companies_me }
  end

  def test_array_query_encodes_as_bracket_pairs
    client(access_token: "tok-123").invoices(expand: %w[events en_invoice])
    q = @requests.find { |r| r[:path] == "/v1.beta/invoices" }[:query]

    assert_includes q, "expand%5B%5D=events"
    assert_includes q, "expand%5B%5D=en_invoice"
  end

  def test_post_sends_json_body_and_content_type
    client(access_token: "tok-123").create_invoice({ en_invoice: { total: 100 } })
    req = @requests.find { |r| r[:path] == "/v1.beta/invoices" && r[:method] == "POST" }

    assert_equal "application/json", req[:headers]["content-type"]
    assert_equal({ "en_invoice" => { "total" => 100 } }, JSON.parse(req[:body]))
  end

  def test_raw_download_returns_untouched_bytes
    bytes = client(access_token: "tok-123").download_invoice(42)

    assert_equal "%PDF-1.4 rawbytes", bytes
  end

  def test_non_json_body_falls_back_to_raw_string
    assert_equal "not json at all", client(access_token: "tok-123").get("/plain")
  end

  def test_each_item_paginates_across_cursor
    ids = client(access_token: "tok-123").each_item("/invoices").map { |i| i["id"] }

    assert_equal [1, 2, 3], ids
  end

  def test_non_2xx_raises_api_error
    err = assert_raises(SuperPDP::APIError) { client(access_token: "tok-123").get("/boom") }
    assert_equal 422, err.status
    assert_match(/nope/, err.message)
  end

  def test_retries_transient_5xx_then_succeeds
    res = client(access_token: "tok-123", retry_base: 0).get("/flaky")

    assert res["ok"]
    assert_equal 3, paths.count("/v1.beta/flaky") # 2 failures + 1 success
  end

  def test_retries_exhausted_raises_api_error
    err = assert_raises(SuperPDP::APIError) do
      client(access_token: "tok-123", retry_base: 0, max_retries: 2).get("/always_503")
    end

    assert_equal 503, err.status
    assert_equal 3, paths.count("/v1.beta/always_503") # 1 initial + 2 retries
  end

  def test_post_is_not_retried
    assert_raises(SuperPDP::APIError) do
      client(access_token: "tok-123", retry_base: 0).post("/always_503")
    end

    assert_equal 1, paths.count("/v1.beta/always_503")
  end

  def test_429_is_retried_honoring_retry_after
    res = client(access_token: "tok-123", retry_base: 0).get("/rate_limited")

    assert res["ok"]
    assert_equal 2, paths.count("/v1.beta/rate_limited")
  end

  def test_sends_user_agent_header
    client(access_token: "tok-123").companies_me
    ua = @requests.find { |r| r[:path] == "/v1.beta/companies/me" }[:headers]["user-agent"]

    assert_match %r{\Asuper_pdp/\d}, ua
  end
end
