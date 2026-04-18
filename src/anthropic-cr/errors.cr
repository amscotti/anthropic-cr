module Anthropic
  # Base error class for all Anthropic API errors
  #
  # `error_type` reflects the `error.type` field from the API's error payload
  # (e.g., `"invalid_request_error"`, `"rate_limit_error"`, `"overloaded_error"`,
  # `"billing_error"`). It is populated whenever the response body parses as
  # JSON and carries a nested `error.type`.
  class APIError < Exception
    getter status : Int32?
    getter body : String?
    getter headers : HTTP::Headers?
    getter error_type : String?

    def initialize(
      message : String,
      @status : Int32? = nil,
      @body : String? = nil,
      @headers : HTTP::Headers? = nil,
      @error_type : String? = nil,
      cause : Exception? = nil,
    )
      super(message, cause)
    end
  end

  # 400 - Bad Request
  class BadRequestError < APIError
  end

  # 401 - Authentication Error
  class AuthenticationError < APIError
  end

  # 403 - Permission Denied
  class PermissionDeniedError < APIError
  end

  # 404 - Not Found
  class NotFoundError < APIError
  end

  # 409 - Conflict
  class ConflictError < APIError
  end

  # 413 - Payload Too Large
  #
  # Raised when the request body exceeds the server's size limits.
  class PayloadTooLargeError < APIError
  end

  # 422 - Unprocessable Entity
  class UnprocessableEntityError < APIError
  end

  # 429 - Rate Limit Error
  class RateLimitError < APIError
    getter retry_after : Int32?

    def initialize(
      message : String,
      status : Int32? = nil,
      body : String? = nil,
      headers : HTTP::Headers? = nil,
      error_type : String? = nil,
      @retry_after : Int32? = nil,
      cause : Exception? = nil,
    )
      super(message, status, body, headers, error_type, cause)
    end
  end

  # >= 500 - Internal Server Error
  class InternalServerError < APIError
  end

  # 504 - Gateway Timeout
  class GatewayTimeoutError < APIError
  end

  # 529 - Overloaded
  #
  # Returned when the API is temporarily overloaded. Typically transient and
  # safe to retry with backoff.
  class OverloadedError < APIError
  end

  # Network/connection errors
  class APIConnectionError < APIError
    def initialize(message : String, cause : Exception? = nil)
      super(message, cause: cause)
    end
  end

  # Timeout errors
  class APITimeoutError < APIConnectionError
  end

  # Structured output parsing errors
  class StructuredOutputParseError < APIError
  end
end
