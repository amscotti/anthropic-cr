module Anthropic
  # HTTP middleware system for inspecting, rewriting, or short-circuiting
  # requests and responses around the SDK's terminal HTTP send.
  #
  # A middleware is any type that includes `Anthropic::Middleware` and
  # implements `#call(request, nxt)`. The chain runs **once per HTTP attempt,
  # inside the SDK's retry loop**, so a middleware observes every retry and may
  # call `nxt` multiple times to implement custom retry logic.
  #
  # `nxt.call(request)` returns an `APIResponse` for **every** HTTP status
  # (4xx/5xx do **not** raise inside the chain — typed error raising happens
  # after the chain returns). Connection-level failures (`APITimeoutError`,
  # `APIConnectionError`) do raise from `nxt.call`.
  #
  # **Limitation:** only buffered JSON requests (GET/POST/DELETE) run through
  # the chain. Streaming (`messages.stream` / `open_stream` / SSE endpoints),
  # raw downloads, and multipart uploads bypass middleware entirely.
  #
  # Registration: `Anthropic::Client.new(middleware: [my_mw])` (outermost first).
  #
  # ```
  # class LoggingMiddleware
  #   include Anthropic::Middleware
  #
  #   def call(request : Anthropic::APIRequest, nxt : Anthropic::MiddlewareNext) : Anthropic::APIResponse
  #     puts "-> #{request.method} #{request.path}"
  #     response = nxt.call(request)
  #     puts "<- #{response.status}"
  #     response
  #   end
  # end
  #
  # client = Anthropic::Client.new(middleware: [LoggingMiddleware.new])
  # ```
  module Middleware
    abstract def call(request : APIRequest, nxt : MiddlewareNext) : APIResponse
  end

  # A normalized, HTTP-shaped request handed to middleware.
  #
  # The `metadata` hash is a mutable cross-attempt scratchpad: middleware may
  # stash state there and read it on retries. Note that `headers` and
  # `metadata` are shared by reference between an original request and copies
  # derived via `#with` — `dup` the headers before mutating them.
  class APIRequest
    getter method : String
    getter path : String
    getter headers : HTTP::Headers
    getter body : String?
    getter metadata : Hash(String, JSON::Any)

    def initialize(@method : String, @path : String, @headers : HTTP::Headers, @body : String? = nil, @metadata = {} of String => JSON::Any)
    end

    # Derive a copy with overridden fields. Passing `nil` (or omitting) a field
    # keeps the original value — a body cannot be cleared through this method.
    def with(*, method : String? = nil, path : String? = nil, headers : HTTP::Headers? = nil, body : String? = nil) : APIRequest
      APIRequest.new(method || @method, path || @path, headers || @headers, body || @body, @metadata)
    end
  end

  # The chain-continuation callable. Invoking it sends the request through the
  # rest of the chain (down to the terminal HTTP send) and returns the response.
  alias MiddlewareNext = Proc(APIRequest, APIResponse)

  # A raw HTTP response surfaced to middleware. Carries every status code;
  # middleware must inspect `status` to react to errors.
  class APIResponse
    getter status : Int32
    getter headers : HTTP::Headers
    getter body : String
    getter request : APIRequest?

    def initialize(@status : Int32, @headers : HTTP::Headers, @body : String, @request : APIRequest? = nil)
    end

    def success? : Bool
      (200..299).includes?(@status)
    end

    # Parse the body as the SDK-typed result. Buffers nothing (body is already
    # materialized for the non-streaming path).
    def parse(type : T.class) : T forall T
      T.from_json(@body)
    end
  end
end
