# frozen_string_literal: true

require "minitest/autorun"
require "socket"
require_relative "../lib/super_pdp"

# Minimal stdlib TCP server so we exercise the real Net::HTTP path:
# token fetch, Bearer auth, array-query encoding, pagination, error mapping.
class SuperPDPTest < Minitest::Test
  def setup
    @requests = []
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
    length = 0
    while (line = conn.gets) && line != "\r\n"
      length = line.split(":", 2)[1].to_i if line =~ /\Acontent-length:/i
    end
    conn.read(length) if length.positive?

    path, query = target.split("?", 2)
    @requests << { method: method, path: path, query: query.to_s }
    conn.write(response_for(path, query.to_s))
    conn.close
  end

  def response_for(path, query)
    body =
      case path
      when "/oauth2/token"
        JSON.generate(access_token: "tok-123", expires_in: 3600)
      when "/v1.beta/companies/me"
        JSON.generate(id: 1, name: "ACME")
      when "/v1.beta/invoices"
        if query.include?("starting_after_id")
          JSON.generate(data: [{ id: 3 }], count: 1, has_after: false, has_before: true)
        else
          JSON.generate(data: [{ id: 1 }, { id: 2 }], count: 2, has_after: true, has_before: false)
        end
      when "/v1.beta/boom"
        return http("422 Unprocessable Entity", JSON.generate(message: "nope"))
      else
        "{}"
      end
    http("200 OK", body)
  end

  def http(status, body)
    "HTTP/1.1 #{status}\r\nContent-Type: application/json\r\n" \
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

  def test_array_query_encodes_as_bracket_pairs
    client(access_token: "tok-123").invoices(expand: %w[events en_invoice])
    q = @requests.find { |r| r[:path] == "/v1.beta/invoices" }[:query]
    assert_includes q, "expand%5B%5D=events"
    assert_includes q, "expand%5B%5D=en_invoice"
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
end
