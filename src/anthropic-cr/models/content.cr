module Anthropic
  # Cache control configuration for prompt caching
  #
  # Prompt caching reduces costs by up to 90% and latency by up to 85%
  # for prompts with large amounts of repeated content.
  #
  # ```
  # # Default 5-minute ephemeral cache
  # cache = Anthropic::CacheControl.ephemeral
  #
  # # Extended 1-hour cache (requires beta header)
  # cache = Anthropic::CacheControl.one_hour
  #
  # # Use in content
  # content = Anthropic::TextContent.new(
  #   text: "Large context...",
  #   cache_control: CacheControl.ephemeral
  # )
  # ```
  #
  # Pricing:
  # - Cache writes (5-min): 1.25x base input token price
  # - Cache writes (1-hour): 2x base input token price
  # - Cache reads: 0.1x base input token price
  struct CacheControl
    include JSON::Serializable

    getter type : String = "ephemeral"

    @[JSON::Field(key: "ttl")]
    getter ttl : Int32?

    def initialize(@type : String = "ephemeral", @ttl : Int32? = nil)
    end

    # Create ephemeral cache control (5-minute TTL, default)
    #
    # Standard caching with 5-minute duration. Cache writes cost 1.25x base price.
    def self.ephemeral : self
      new(type: "ephemeral")
    end

    # Create extended cache control (1-hour TTL)
    #
    # Extended caching for longer context retention. Cache writes cost 2x base price.
    # Requires the beta header: `extended-cache-ttl-2025-04-11`
    #
    # ```
    # # Use via beta.messages.create with the beta header
    # client.beta.messages.create(
    #   betas: [Anthropic::EXTENDED_CACHE_TTL_BETA],
    #   model: ...,
    #   messages: [...]
    # )
    # ```
    def self.one_hour : self
      new(type: "ephemeral", ttl: 3600)
    end

    # Create cache control with custom TTL in seconds
    #
    # Note: Custom TTLs may require specific beta headers.
    def self.with_ttl(seconds : Int32) : self
      new(type: "ephemeral", ttl: seconds)
    end
  end

  # Text content block
  struct TextContent
    include JSON::Serializable

    getter type : String = "text"
    getter text : String

    @[JSON::Field(key: "cache_control")]
    getter cache_control : CacheControl?

    def initialize(@text : String, @cache_control : CacheControl? = nil)
    end
  end

  # Image source types
  struct Base64ImageSource
    include JSON::Serializable

    getter type : String = "base64"

    @[JSON::Field(key: "media_type")]
    getter media_type : String

    getter data : String

    def initialize(@media_type : String, @data : String)
      @type = "base64"
    end
  end

  struct URLImageSource
    include JSON::Serializable

    getter type : String = "url"
    getter url : String

    def initialize(@url : String)
      @type = "url"
    end
  end

  alias ImageSource = Base64ImageSource | URLImageSource

  # Image content block
  struct ImageContent
    include JSON::Serializable

    getter type : String = "image"
    getter source : ImageSource

    @[JSON::Field(key: "cache_control")]
    getter cache_control : CacheControl?

    def initialize(@source : ImageSource, @cache_control : CacheControl? = nil)
      @type = "image"
    end

    # Factory method for base64 images
    def self.base64(media_type : String, data : String, cache_control : CacheControl? = nil) : self
      new(
        source: Base64ImageSource.new(media_type: media_type, data: data),
        cache_control: cache_control
      )
    end

    # Factory method for URL images
    def self.url(url : String, cache_control : CacheControl? = nil) : self
      new(
        source: URLImageSource.new(url: url),
        cache_control: cache_control
      )
    end
  end

  # Tool use content block (from assistant)
  #
  # When Claude calls a tool, the input is returned as dynamic JSON.
  # Use `input_as` to parse it into a typed struct:
  #
  # ```
  # struct GetWeatherInput
  #   include JSON::Serializable
  #   getter location : String
  #   getter unit : String?
  # end
  #
  # tool_use = message.tool_use_blocks.first
  # if tool_use.name == "get_weather"
  #   input = tool_use.input_as(GetWeatherInput)
  #   puts input.location # Typed access!
  # end
  # ```
  struct ToolUseContent
    include JSON::Serializable

    getter type : String = "tool_use"
    getter id : String
    getter name : String
    getter input : JSON::Any

    def initialize(@id : String, @name : String, @input : JSON::Any)
      @type = "tool_use"
    end

    # Parse input into a typed struct
    #
    # Use this when you know which tool was called and want typed access
    # to the input parameters.
    #
    # ```
    # input = tool_use.input_as(MyToolInput)
    # puts input.some_field # Type-safe!
    # ```
    def input_as(type : T.class) : T forall T
      T.from_json(input.to_json)
    end
  end

  # Tool result content block (from user)
  struct ToolResultContent
    include JSON::Serializable

    getter type : String = "tool_result"

    @[JSON::Field(key: "tool_use_id")]
    getter tool_use_id : String

    getter content : String | Array(TextContent | ImageContent)?

    @[JSON::Field(key: "is_error")]
    getter is_error : Bool?

    def initialize(@tool_use_id : String, @content : String | Array(TextContent | ImageContent)? = nil, @is_error : Bool? = nil)
      @type = "tool_result"
    end
  end

  # Thinking content block (extended thinking)
  struct ThinkingContent
    include JSON::Serializable

    getter type : String = "thinking"
    getter thinking : String
    getter signature : String

    def initialize(@thinking : String, @signature : String)
      @type = "thinking"
    end
  end

  # Redacted thinking content block (extended thinking)
  #
  # Returned when thinking content has been redacted by the API.
  # Must be preserved and passed back in multi-turn conversations.
  struct RedactedThinkingContent
    include JSON::Serializable

    getter type : String = "redacted_thinking"
    getter data : String

    def initialize(@data : String)
    end
  end

  # Document source types (placeholder for future implementation)
  # These will be implemented when the Files API is added
  struct Base64PDFSource
    include JSON::Serializable

    getter type : String = "base64"

    @[JSON::Field(key: "media_type")]
    getter media_type : String = "application/pdf"

    getter data : String

    def initialize(@data : String)
      @type = "base64"
    end
  end

  struct PlainTextSource
    include JSON::Serializable

    getter type : String = "text"

    @[JSON::Field(key: "media_type")]
    getter media_type : String = "text/plain"

    getter data : String

    def initialize(@data : String)
      @type = "text"
    end
  end

  struct URLPDFSource
    include JSON::Serializable

    getter type : String = "url"
    getter url : String

    def initialize(@url : String)
      @type = "url"
    end
  end

  # File-based document source (references uploaded file by ID)
  #
  # ```
  # # Upload a file first
  # file = client.beta.files.upload(Path["document.pdf"])
  #
  # # Reference it in a message
  # source = Anthropic::FileSource.new(file.id)
  # ```
  struct FileSource
    include JSON::Serializable

    getter type : String = "file"

    @[JSON::Field(key: "file_id")]
    getter file_id : String

    def initialize(@file_id : String)
      @type = "file"
    end
  end

  alias DocumentSource = Base64PDFSource | PlainTextSource | URLPDFSource | FileSource

  # Document content block
  struct DocumentContent
    include JSON::Serializable

    getter type : String = "document"
    getter source : DocumentSource
    getter title : String?
    getter context : String?
    getter citations : CitationConfig?

    @[JSON::Field(key: "cache_control")]
    getter cache_control : CacheControl?

    def initialize(
      @source : DocumentSource,
      @title : String? = nil,
      @context : String? = nil,
      @citations : CitationConfig? = nil,
      @cache_control : CacheControl? = nil,
    )
      @type = "document"
    end

    # Create a document from plain text with optional citations
    def self.text(
      content : String,
      title : String? = nil,
      context : String? = nil,
      citations : Bool = false,
      cache_control : CacheControl? = nil,
    ) : self
      new(
        source: PlainTextSource.new(content),
        title: title,
        context: context,
        citations: citations ? CitationConfig.enable : nil,
        cache_control: cache_control
      )
    end

    # Create a document from base64-encoded PDF with optional citations
    def self.pdf(
      data : String,
      title : String? = nil,
      context : String? = nil,
      citations : Bool = false,
      cache_control : CacheControl? = nil,
    ) : self
      new(
        source: Base64PDFSource.new(data),
        title: title,
        context: context,
        citations: citations ? CitationConfig.enable : nil,
        cache_control: cache_control
      )
    end

    # Create a document from URL with optional citations
    def self.url(
      url : String,
      title : String? = nil,
      context : String? = nil,
      citations : Bool = false,
      cache_control : CacheControl? = nil,
    ) : self
      new(
        source: URLPDFSource.new(url),
        title: title,
        context: context,
        citations: citations ? CitationConfig.enable : nil,
        cache_control: cache_control
      )
    end

    # Create a document from an uploaded file ID with optional citations
    #
    # ```
    # # Upload a file first
    # file = client.beta.files.upload(Path["document.pdf"])
    #
    # # Reference it in a message
    # doc = Anthropic::DocumentContent.file(file.id, title: "My Document", citations: true)
    # ```
    def self.file(
      file_id : String,
      title : String? = nil,
      context : String? = nil,
      citations : Bool = false,
      cache_control : CacheControl? = nil,
    ) : self
      new(
        source: FileSource.new(file_id),
        title: title,
        context: context,
        citations: citations ? CitationConfig.enable : nil,
        cache_control: cache_control
      )
    end
  end

  # Search result content block (input content)
  #
  # Used to provide search results as context in messages.
  struct SearchResultContent
    include JSON::Serializable

    getter type : String = "search_result"
    getter source : String
    getter title : String
    getter content : Array(TextContent)

    @[JSON::Field(key: "cache_control", emit_null: false)]
    getter cache_control : CacheControl?

    @[JSON::Field(emit_null: false)]
    getter citations : CitationConfig?

    def initialize(
      @source : String,
      @title : String,
      @content : Array(TextContent),
      @cache_control : CacheControl? = nil,
      @citations : CitationConfig? = nil,
    )
    end
  end

  # Compaction content block
  #
  # Returned during auto-compaction of conversation history.
  struct CompactionContent
    include JSON::Serializable

    getter type : String = "compaction"
    getter content : String?

    def initialize(@content : String? = nil)
    end
  end

  # Citation configuration for documents
  struct CitationConfig
    include JSON::Serializable

    getter? enabled : Bool

    def initialize(@enabled : Bool = true)
    end

    def self.enable : self
      new(enabled: true)
    end
  end

  # Citation reference in a response
  struct Citation
    include JSON::Serializable

    @[JSON::Field(key: "document_title")]
    getter document_title : String?

    @[JSON::Field(key: "document_index")]
    getter document_index : Int32?

    @[JSON::Field(key: "start_char")]
    getter start_char : Int32

    @[JSON::Field(key: "end_char")]
    getter end_char : Int32

    @[JSON::Field(key: "cited_text")]
    getter cited_text : String?

    def initialize(
      @start_char : Int32,
      @end_char : Int32,
      @document_title : String? = nil,
      @document_index : Int32? = nil,
      @cited_text : String? = nil,
    )
    end
  end

  # Text content with citation support
  struct TextContentWithCitations
    include JSON::Serializable

    getter type : String = "text"
    getter text : String
    getter citations : Array(Citation)?

    def initialize(@text : String, @citations : Array(Citation)? = nil)
    end
  end

  # Extended thinking configuration
  #
  # Enable extended thinking to let Claude show its reasoning process.
  #
  # ```
  # # Enable with token budget
  # thinking: Anthropic::ThinkingConfig.enabled(budget_tokens: 1600)
  #
  # # Or disable
  # thinking: Anthropic::ThinkingConfig.disabled
  # ```
  struct ThinkingConfig
    include JSON::Serializable

    getter type : String

    @[JSON::Field(key: "budget_tokens")]
    getter budget_tokens : Int32?

    def initialize(@type : String, @budget_tokens : Int32? = nil)
    end

    # Enable extended thinking with a token budget
    def self.enabled(budget_tokens : Int32) : self
      new(type: "enabled", budget_tokens: budget_tokens)
    end

    # Disable extended thinking
    def self.disabled : self
      new(type: "disabled")
    end

    # Adaptive thinking (Opus 4.6+)
    #
    # Lets the model decide how much thinking to use based on the task.
    def self.adaptive : self
      new(type: "adaptive")
    end
  end

  # Union type for all content blocks (including server tool content)
  alias ContentBlock = TextContent | ImageContent | ToolUseContent | ToolResultContent |
                       ThinkingContent | RedactedThinkingContent | DocumentContent |
                       SearchResultContent | CompactionContent |
                       ServerToolUseContent | WebSearchToolResultContent |
                       CodeExecutionToolResultContent | WebFetchToolResultContent |
                       MCPToolUseContent | MCPToolResultContent

  # JSON converter for discriminated union parsing of content blocks
  #
  # Parses content blocks based on their `type` field into the appropriate struct.
  # Used by Message to provide typed content access.
  module ContentBlockConverter
    def self.from_json(pull : JSON::PullParser) : ContentBlock
      json = JSON::Any.new(pull)
      type = json["type"]?.try(&.as_s)
      raw = json.to_json

      parse_core_block(type, raw) ||
        parse_server_block(type, raw) ||
        TextContent.new(text: raw)
    end

    private def self.parse_core_block(type : String?, raw : String) : ContentBlock?
      case type
      when "text"              then TextContent.from_json(raw)
      when "tool_use"          then ToolUseContent.from_json(raw)
      when "tool_result"       then ToolResultContent.from_json(raw)
      when "thinking"          then ThinkingContent.from_json(raw)
      when "redacted_thinking" then RedactedThinkingContent.from_json(raw)
      when "image"             then ImageContent.from_json(raw)
      when "document"          then DocumentContent.from_json(raw)
      when "search_result"     then SearchResultContent.from_json(raw)
      when "compaction"        then CompactionContent.from_json(raw)
      end
    end

    private def self.parse_server_block(type : String?, raw : String) : ContentBlock?
      case type
      when "server_tool_use"            then ServerToolUseContent.from_json(raw)
      when "web_search_tool_result"     then WebSearchToolResultContent.from_json(raw)
      when "code_execution_tool_result" then CodeExecutionToolResultContent.from_json(raw)
      when "web_fetch_tool_result"      then WebFetchToolResultContent.from_json(raw)
      when "mcp_tool_use"               then MCPToolUseContent.from_json(raw)
      when "mcp_tool_result"            then MCPToolResultContent.from_json(raw)
      end
    end

    def self.to_json(value : ContentBlock, builder : JSON::Builder)
      value.to_json(builder)
    end
  end

  # JSON converter for arrays of content blocks
  module ContentBlockArrayConverter
    def self.from_json(pull : JSON::PullParser) : Array(ContentBlock)
      result = [] of ContentBlock
      pull.read_array do
        result << ContentBlockConverter.from_json(pull)
      end
      result
    end

    def self.to_json(value : Array(ContentBlock), builder : JSON::Builder)
      builder.array do
        value.each(&.to_json(builder))
      end
    end
  end
end
