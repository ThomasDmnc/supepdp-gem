# frozen_string_literal: true

module SuperPDP
  class Error < StandardError; end

  # Raised for any non-2xx HTTP response. Carries the status and parsed body.
  class APIError < Error
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body = body
      message = body.is_a?(Hash) ? (body["message"] || body["error"] || body.to_s) : body.to_s
      super("SuperPDP API error #{status}: #{message}")
    end
  end

  class AuthError < Error; end
end
