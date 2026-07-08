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

  # Status-specific subclasses so callers can rescue by kind. All subclass
  # APIError, so `rescue SuperPDP::APIError` still catches every non-2xx.
  # 401, 403
  class UnauthorizedError < APIError; end
  # 404
  class NotFoundError < APIError; end

  # 429
  class RateLimitError < APIError
    attr_reader :retry_after # integer seconds from Retry-After, or nil

    def initialize(status, body, retry_after = nil)
      @retry_after = retry_after
      super(status, body)
    end
  end

  # Token/credential-refresh failures (not an HTTP APIError).
  class AuthError < Error; end
end
