require "../../spec_helper"

describe Anthropic::MCP do
  describe ".content" do
    it "converts text blocks" do
      block = Anthropic::MCP.content(JSON.parse(%({"type":"text","text":"hello"})))
      text = block.as(Anthropic::TextContent)
      text.text.should eq("hello")
    end

    it "converts image blocks with supported MIME types" do
      block = Anthropic::MCP.content(JSON.parse(%({"type":"image","data":"aGk=","mimeType":"image/png"})))
      image = block.as(Anthropic::ImageContent)
      source = image.source.as(Anthropic::Base64ImageSource)
      source.media_type.should eq("image/png")
      source.data.should eq("aGk=")
    end

    it "rejects unsupported image MIME types" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "Unsupported image MIME type") do
        Anthropic::MCP.content(JSON.parse(%({"type":"image","data":"aGk=","mimeType":"image/tiff"})))
      end
    end

    it "rejects audio and resource links" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "Unsupported MCP content type: audio") do
        Anthropic::MCP.content(JSON.parse(%({"type":"audio","data":"aGk=","mimeType":"audio/mp3"})))
      end
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "resource_link") do
        Anthropic::MCP.content(JSON.parse(%({"type":"resource_link","uri":"file:///x"})))
      end
    end

    it "converts embedded resources" do
      block = Anthropic::MCP.content(JSON.parse(%({"type":"resource","resource":{"uri":"file:///n.txt","mimeType":"text/plain","text":"notes"}})))
      doc = block.as(Anthropic::DocumentContent)
      doc.source.as(Anthropic::PlainTextSource).data.should eq("notes")
    end

    it "converts embedded image resources" do
      block = Anthropic::MCP.content(JSON.parse(%({"type":"resource","resource":{"uri":"file:///i.png","mimeType":"image/png","blob":"aGk="}})))
      image = block.as(Anthropic::ImageContent)
      image.source.as(Anthropic::Base64ImageSource).media_type.should eq("image/png")
    end

    it "rejects unknown types and malformed items" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "Unsupported MCP content type") do
        Anthropic::MCP.content(JSON.parse(%({"type":"video","data":"x"})))
      end
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "missing required field: text") do
        Anthropic::MCP.content(JSON.parse(%({"type":"text"})))
      end
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "must be an object") do
        Anthropic::MCP.content(JSON.parse(%("nope")))
      end
    end
  end

  describe ".message and .messages" do
    it "converts prompt messages" do
      message = Anthropic::MCP.message(JSON.parse(%({"role":"user","content":{"type":"text","text":"hi"}})))
      message.role.should eq("user")
      message.content.as(Array(Anthropic::ContentBlock)).first.as(Anthropic::TextContent).text.should eq("hi")

      messages = Anthropic::MCP.messages([
        JSON.parse(%({"role":"user","content":{"type":"text","text":"hi"}})),
        JSON.parse(%({"role":"assistant","content":{"type":"text","text":"hello"}})),
      ])
      messages.size.should eq(2)
      messages[1].role.should eq("assistant")
    end
  end

  describe ".resource_to_content" do
    it "uses the first supported entry" do
      result = JSON.parse(%({"contents":[
        {"uri":"file:///b.bin","mimeType":"application/octet-stream","blob":"aGk="},
        {"uri":"file:///d.pdf","mimeType":"application/pdf","blob":"aGk="}
      ]}))
      doc = Anthropic::MCP.resource_to_content(result).as(Anthropic::DocumentContent)
      doc.source.should be_a(Anthropic::Base64PDFSource)
    end

    it "decodes text blobs" do
      result = JSON.parse(%({"contents":[{"uri":"file:///n.txt","blob":"aGVsbG8="}]}))
      doc = Anthropic::MCP.resource_to_content(result).as(Anthropic::DocumentContent)
      doc.source.as(Anthropic::PlainTextSource).data.should eq("hello")
    end

    it "raises on empty or unsupported contents" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "at least one item") do
        Anthropic::MCP.resource_to_content(JSON.parse(%({"contents":[]})))
      end
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "No supported MIME type") do
        Anthropic::MCP.resource_to_content(JSON.parse(%({"contents":[{"uri":"file:///b.bin","mimeType":"application/octet-stream","blob":"aGk="}]})))
      end
    end

    it "requires blob data for images and PDFs" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "must have blob data") do
        Anthropic::MCP.resource_to_content(JSON.parse(%({"contents":[{"uri":"file:///i.png","mimeType":"image/png","text":"nope"}]})))
      end
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "must have blob data") do
        Anthropic::MCP.resource_to_content(JSON.parse(%({"contents":[{"uri":"file:///d.pdf","mimeType":"application/pdf","text":"nope"}]})))
      end
    end

    it "rejects text resources with neither text nor blob" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "must have text or blob data") do
        Anthropic::MCP.resource_to_content(JSON.parse(%({"contents":[{"uri":"file:///n.txt","mimeType":"text/plain"}]})))
      end
    end

    it "rejects invalid base64 blobs" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "not valid base64") do
        Anthropic::MCP.resource_to_content(JSON.parse(%({"contents":[{"uri":"file:///n.txt","blob":"%%%"}]})))
      end
    end

    it "rejects results without a contents array" do
      expect_raises(Anthropic::MCP::UnsupportedMCPValueError, "at least one item") do
        Anthropic::MCP.resource_to_content(JSON.parse(%({"uri":"file:///n.txt"})))
      end
    end
  end
end
