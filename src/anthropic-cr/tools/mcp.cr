module Anthropic
  # Convert Model Context Protocol payloads into Anthropic content blocks.
  #
  # This is a dependency-free port of the content converters from the
  # TypeScript SDK's `helpers/beta/mcp` module: inputs are raw `JSON::Any`
  # values shaped like MCP SDK responses, so no MCP client library is
  # needed.
  #
  # ```
  # content = JSON.parse(%({"type":"text","text":"hello"}))
  # block = Anthropic::MCP.content(content)
  # ```
  module MCP
    # Raised when an MCP value cannot be represented as an Anthropic
    # content block (unsupported content type or MIME type).
    class UnsupportedMCPValueError < ArgumentError
    end

    SUPPORTED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"]

    # Convert one MCP prompt content item to an Anthropic content block.
    #
    # Handles `text`, `image`, and embedded `resource` items. `audio` and
    # `resource_link` items are rejected, as is any unknown `type`.
    # Malformed items raise `UnsupportedMCPValueError`.
    def self.content(block : JSON::Any) : ContentBlock
      hash = block.as_h? || raise UnsupportedMCPValueError.new("MCP content must be an object")

      case hash["type"]?.try(&.as_s?)
      when "text"
        # MCP annotations (audience/priority) have no Anthropic equivalent
        # and are dropped.
        text = hash["text"]?.try(&.as_s?) || raise UnsupportedMCPValueError.new("MCP text content is missing required field: text")
        TextContent.new(text: text)
      when "image"
        mime = hash["mimeType"]?.try(&.as_s?) || ""
        unless SUPPORTED_IMAGE_TYPES.includes?(mime)
          raise UnsupportedMCPValueError.new("Unsupported image MIME type: #{mime}")
        end
        data = hash["data"]?.try(&.as_s?) || raise UnsupportedMCPValueError.new("MCP image content is missing required field: data")
        ImageContent.base64(mime, data)
      when "resource"
        resource = hash["resource"]? || raise UnsupportedMCPValueError.new("MCP resource content is missing required field: resource")
        resource_content_to_block(resource)
      when "resource_link", "audio"
        raise UnsupportedMCPValueError.new("Unsupported MCP content type: #{hash["type"]}")
      else
        raise UnsupportedMCPValueError.new("Unsupported MCP content type: #{hash["type"]?}")
      end
    end

    # Convert one MCP prompt message to an Anthropic message param.
    def self.message(message : JSON::Any) : MessageParam
      role = message["role"]?.try(&.as_s?) || raise UnsupportedMCPValueError.new("MCP message is missing required field: role")
      body = message["content"]? || raise UnsupportedMCPValueError.new("MCP message is missing required field: content")
      MessageParam.new(role: role, content: [content(body)] of ContentBlock)
    end

    # Convert MCP prompt messages (e.g. from `getPrompt`) to Anthropic
    # message params.
    def self.messages(messages : Array(JSON::Any)) : Array(MessageParam)
      messages.map { |message| self.message(message) }
    end

    # Convert MCP resource contents (e.g. from `readResource`) to a
    # single Anthropic content block.
    #
    # Uses the first entry with a supported MIME type: images become
    # image blocks, PDFs and `text/*` entries become documents.
    def self.resource_to_content(result : JSON::Any) : ContentBlock
      contents = result["contents"]?.try(&.as_a?) || [] of JSON::Any
      if contents.empty?
        raise UnsupportedMCPValueError.new("Resource contents array must contain at least one item")
      end

      supported = contents.find { |entry| supported_resource_mime?(entry["mimeType"]?.try(&.as_s?)) }
      unless supported
        available = contents.compact_map { |entry| entry["mimeType"]?.try(&.as_s?) }.join(", ")
        raise UnsupportedMCPValueError.new("No supported MIME type found in resource contents. Available: #{available}")
      end

      resource_content_to_block(supported)
    end

    private def self.supported_resource_mime?(mime : String?) : Bool
      return true if mime.nil?
      return true if mime.starts_with?("text/")
      return true if mime == "application/pdf"
      SUPPORTED_IMAGE_TYPES.includes?(mime)
    end

    private def self.resource_content_to_block(entry : JSON::Any) : ContentBlock
      mime = entry["mimeType"]?.try(&.as_s?)
      uri = entry["uri"]?.try(&.as_s?) || ""

      if mime && SUPPORTED_IMAGE_TYPES.includes?(mime)
        blob = entry["blob"]?.try(&.as_s?)
        unless blob
          raise UnsupportedMCPValueError.new("Image resource must have blob data, not text. URI: #{uri}")
        end
        return ImageContent.base64(mime, blob)
      end

      if mime == "application/pdf"
        blob = entry["blob"]?.try(&.as_s?)
        unless blob
          raise UnsupportedMCPValueError.new("PDF resource must have blob data, not text. URI: #{uri}")
        end
        return DocumentContent.pdf(blob)
      end

      if mime.nil? || mime.starts_with?("text/")
        text = entry["text"]?.try(&.as_s?)
        if text.nil? && (blob = entry["blob"]?.try(&.as_s?))
          begin
            text = Base64.decode_string(blob)
          rescue Base64::Error
            raise UnsupportedMCPValueError.new("Text resource blob is not valid base64. URI: #{uri}")
          end
        end
        unless text
          raise UnsupportedMCPValueError.new("Text resource must have text or blob data. URI: #{uri}")
        end
        return DocumentContent.text(text)
      end

      raise UnsupportedMCPValueError.new("Unsupported MIME type \"#{mime}\" for resource: #{uri}")
    end
  end
end
