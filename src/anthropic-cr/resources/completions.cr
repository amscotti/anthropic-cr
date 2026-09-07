module Anthropic
  # [Legacy] Text Completions API resource.
  #
  # The Text Completions API is a legacy API; prefer `client.messages` for
  # new code. Future models and features will not be compatible with Text
  # Completions.
  #
  # ```
  # completion = client.completions.create(
  #   model: "claude-haiku-4-5-20251001",
  #   prompt: "\n\nHuman: Hello!\n\nAssistant:",
  #   max_tokens_to_sample: 256
  # )
  # puts completion.completion
  # ```
  class Completions
    def initialize(@client : Client)
    end

    # Create a text completion (non-streaming).
    #
    # Raises `ArgumentError` when `stream` is true; use `#stream` instead
    # (mirrors the official Ruby/TypeScript SDKs).
    def create(
      model : String,
      prompt : String,
      max_tokens_to_sample : Int32,
      metadata : Metadata? = nil,
      stop_sequences : Array(String)? = nil,
      temperature : Float64? = nil,
      top_k : Int32? = nil,
      top_p : Float64? = nil,
      stream : Bool = false,
      betas : Array(String)? = nil,
      workspace_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
    ) : Completion
      if stream
        raise ArgumentError.new("Please use #stream for the streaming use case.")
      end

      body = completion_body(
        model: model,
        prompt: prompt,
        max_tokens_to_sample: max_tokens_to_sample,
        metadata: metadata,
        stop_sequences: stop_sequences,
        temperature: temperature,
        top_k: top_k,
        top_p: top_p,
        stream: false
      )

      response = @client.post("/v1/complete", body, headers(betas, workspace_id, extra_headers))
      Completion.from_json(response.body)
    end

    # Create a streaming text completion, yielding each `Completion` chunk.
    #
    # ```
    # client.completions.stream(
    #   model: "claude-haiku-4-5-20251001",
    #   prompt: "\n\nHuman: Hello!\n\nAssistant:",
    #   max_tokens_to_sample: 256
    # ) do |chunk|
    #   print chunk.completion
    # end
    # ```
    #
    # Raises `ArgumentError` when `stream` is false; use `#create` instead.
    def stream(
      model : String,
      prompt : String,
      max_tokens_to_sample : Int32,
      metadata : Metadata? = nil,
      stop_sequences : Array(String)? = nil,
      temperature : Float64? = nil,
      top_k : Int32? = nil,
      top_p : Float64? = nil,
      stream : Bool = true,
      betas : Array(String)? = nil,
      workspace_id : String? = nil,
      extra_headers : Hash(String, String)? = nil,
      & : Completion -> _
    )
      unless stream
        raise ArgumentError.new("Please use #create for the non-streaming use case.")
      end

      body = completion_body(
        model: model,
        prompt: prompt,
        max_tokens_to_sample: max_tokens_to_sample,
        metadata: metadata,
        stop_sequences: stop_sequences,
        temperature: temperature,
        top_k: top_k,
        top_p: top_p,
        stream: true
      )

      @client.post_stream("/v1/complete", body, headers(betas, workspace_id, extra_headers)) do |response|
        each_completion(response) do |chunk|
          yield chunk
        end
      end
    end

    private def completion_body(
      model : String,
      prompt : String,
      max_tokens_to_sample : Int32,
      metadata : Metadata?,
      stop_sequences : Array(String)?,
      temperature : Float64?,
      top_k : Int32?,
      top_p : Float64?,
      stream : Bool,
    ) : Hash(String, JSON::Any)
      body = {} of String => JSON::Any
      body["model"] = JSON::Any.new(model)
      body["prompt"] = JSON::Any.new(prompt)
      body["max_tokens_to_sample"] = JSON::Any.new(max_tokens_to_sample.to_i64)
      body["metadata"] = JSON.parse(metadata.to_json) if metadata
      body["stop_sequences"] = JSON.parse(stop_sequences.to_json) if stop_sequences
      body["temperature"] = JSON::Any.new(temperature) if temperature
      body["top_k"] = JSON::Any.new(top_k.to_i64) if top_k
      body["top_p"] = JSON::Any.new(top_p) if top_p
      body["stream"] = JSON::Any.new(stream)
      body
    end

    private def headers(
      betas : Array(String)?,
      workspace_id : String?,
      extra_headers : Hash(String, String)?,
    ) : Hash(String, String)?
      merged : Hash(String, String)? = nil
      if betas && !betas.empty?
        merged = {"anthropic-beta" => betas.join(",")}
      end
      merged = Anthropic.merge_workspace_header(merged, workspace_id)
      return merged if extra_headers.nil? || extra_headers.empty?
      (merged || {} of String => String).merge(extra_headers)
    end

    # Parse SSE `data:` lines from a completion stream into chunks.
    private def each_completion(response : HTTP::Client::Response, & : Completion -> _)
      data_lines = [] of String

      flush = ->(lines : Array(String)) do
        data = lines.join("\n")
        lines.clear
        if data.empty? || data == "[DONE]"
          nil
        else
          begin
            Completion.from_json(data)
          rescue ex : JSON::ParseException
            # Skip malformed chunks, consistent with message streaming.
            nil
          end
        end
      end

      begin
        response.body_io.each_line do |raw_line|
          line = raw_line.ends_with?('\r') ? raw_line[0...-1] : raw_line

          if line.empty?
            if chunk = flush.call(data_lines)
              yield chunk
            end
            next
          end

          next if line.starts_with?(":")

          if line.starts_with?("data: ")
            data_lines << line[6..]
          end
        end
      rescue ex : IO::TimeoutError
        raise APITimeoutError.new("Stream read timed out", cause: ex)
      rescue ex : IO::Error | Socket::Error
        raise APIConnectionError.new("Stream connection failed: #{ex.message}", cause: ex)
      end

      if chunk = flush.call(data_lines)
        yield chunk
      end
    end
  end
end
