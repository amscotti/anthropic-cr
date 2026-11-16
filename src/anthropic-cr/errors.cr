module Anthropic
  # Raised when client configuration is invalid before sending a request.
  class ConfigurationError < Exception
  end

  # API error category constants returned in `error.type`.
  module ErrorType
    INVALID_REQUEST_ERROR            = "invalid_request_error"
    AUTHENTICATION_ERROR             = "authentication_error"
    BILLING_ERROR                    = "billing_error"
    PERMISSION_ERROR                 = "permission_error"
    NOT_FOUND_ERROR                  = "not_found_error"
    RATE_LIMIT_ERROR                 = "rate_limit_error"
    TIMEOUT_ERROR                    = "timeout_error"
    API_ERROR                        = "api_error"
    OVERLOADED_ERROR                 = "overloaded_error"
    MEMORY_PRECONDITION_FAILED_ERROR = "memory_precondition_failed_error"
    MEMORY_PATH_CONFLICT_ERROR       = "memory_path_conflict_error"
    CONFLICT_ERROR                   = "conflict_error"

    ALL = [
      INVALID_REQUEST_ERROR,
      AUTHENTICATION_ERROR,
      BILLING_ERROR,
      PERMISSION_ERROR,
      NOT_FOUND_ERROR,
      RATE_LIMIT_ERROR,
      TIMEOUT_ERROR,
      API_ERROR,
      OVERLOADED_ERROR,
      MEMORY_PRECONDITION_FAILED_ERROR,
      MEMORY_PATH_CONFLICT_ERROR,
      CONFLICT_ERROR,
    ]
  end

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
    getter api_message : String?
    getter error_code : String?
    getter details : ErrorDetails | JSON::Any?

    # Workspace ID echoed by the API in the `anthropic-workspace-id`
    # response header, when the request ran under a Workspace.
    def workspace_id : String?
      @headers.try(&.["anthropic-workspace-id"]?)
    end

    # Request ID echoed by the API in the `request-id` response
    # header. Include it when reporting failures to Anthropic support.
    def request_id : String?
      @headers.try(&.["request-id"]?)
    end

    def initialize(
      message : String,
      @status : Int32? = nil,
      @body : String? = nil,
      @headers : HTTP::Headers? = nil,
      @error_type : String? = nil,
      cause : Exception? = nil,
      @api_message : String? = nil,
      @error_code : String? = nil,
      @details : ErrorDetails | JSON::Any? = nil,
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

  # 408 - Request Timeout
  class RequestTimeoutError < APIError
  end

  # 409 - Conflict
  class ConflictError < APIError
  end

  # 412 - Precondition Failed
  class PreconditionFailedError < APIError
  end

  # 413 - Content Too Large (formerly Payload Too Large)
  #
  # Raised when the request body exceeds the server's size limits.
  class ContentTooLargeError < APIError
  end

  # Backwards-compatible alias for 413 Content Too Large.
  alias PayloadTooLargeError = ContentTooLargeError

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
      api_message : String? = nil,
      error_code : String? = nil,
      details : ErrorDetails | JSON::Any? = nil,
    )
      super(
        message,
        status: status,
        body: body,
        headers: headers,
        error_type: error_type,
        cause: cause,
        api_message: api_message,
        error_code: error_code,
        details: details,
      )
    end
  end

  # 431 - Request Header Fields Too Large
  class RequestHeaderFieldsTooLargeError < APIError
  end

  # 499 - Client Closed Request
  class ClientClosedRequestError < APIError
  end

  # >= 500 - Internal Server Error
  class InternalServerError < APIError
  end

  # 501 - Not Implemented
  #
  # Named `HTTPNotImplementedError` so `::NotImplementedError` from Crystal's
  # stdlib is never shadowed inside `module Anthropic`.
  class HTTPNotImplementedError < InternalServerError
  end

  # 503 - Service Unavailable
  class ServiceUnavailableError < InternalServerError
  end

  # 504 - Gateway Timeout
  class GatewayTimeoutError < InternalServerError
  end

  # 529 - Overloaded
  #
  # Returned when the API is temporarily overloaded. Typically transient and
  # safe to retry with backoff.
  class OverloadedError < InternalServerError
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
