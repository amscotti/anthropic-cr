module Anthropic
  # Base error class for all Anthropic API errors
  class APIError < Exception
    getter status : Int32?
    getter body : String?
    getter headers : HTTP::Headers?

    def initialize(message : String, @status : Int32? = nil, @body : String? = nil, @headers : HTTP::Headers? = nil, cause : Exception? = nil)
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

  # 422 - Unprocessable Entity
  class UnprocessableEntityError < APIError
  end

  # 429 - Rate Limit Error
  class RateLimitError < APIError
    getter retry_after : Int32?

    def initialize(message : String, status : Int32? = nil, body : String? = nil, headers : HTTP::Headers? = nil, @retry_after : Int32? = nil, cause : Exception? = nil)
      super(message, status, body, headers, cause)
    end
  end

  # >= 500 - Internal Server Error
  class InternalServerError < APIError
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
end
