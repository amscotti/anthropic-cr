require "../src/anthropic-cr"
require "dotenv"

# Citations example: Using document citations for source attribution
#
# Citations allow Claude to reference specific parts of documents when
# answering questions, providing source attribution for its responses.
#
# Make sure ANTHROPIC_API_KEY is set in your environment or .env file
#
# Run with:
#   crystal run examples/14_citations.cr

# Load .env file if it exists
Dotenv.load if File.exists?(".env")

client = Anthropic::Client.new

puts "Citations Example"
puts "=" * 60
puts

# Sample document content
document_text = <<-TEXT
The Crystal programming language was first released in 2014. It was created by
Ary Borenszweig and Juan Wajnerman at Manas Technology Solutions. Crystal is a
statically typed, compiled language with syntax inspired by Ruby.

Key features of Crystal include:
- Type inference: Crystal infers types at compile time
- Null safety: The compiler prevents null pointer exceptions
- Macros: Crystal supports compile-time metaprogramming
- C bindings: Easy integration with C libraries
- Concurrency: Built-in support for fibers and channels

Crystal compiles to efficient native code using LLVM. The language aims to have
the elegance of Ruby with the performance of C. Version 1.0 was released in
March 2021, marking the language's stability milestone.
TEXT

# Example 1: Basic citations with document
puts "Example 1: Document citations (non-streaming)"
puts "-" * 60

# Create document with citations enabled
document = Anthropic::DocumentContent.text(
  document_text,
  title: "Crystal Programming Language Overview",
  citations: true
)

message = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    Anthropic::MessageParam.new(
      role: Anthropic::Role::User,
      content: [
        document,
        Anthropic::TextContent.new("When was Crystal 1.0 released? Who created Crystal?"),
      ] of Anthropic::ContentBlock
    ),
  ]
)

puts "Response:"
message.text_blocks.each { |block| puts block.text }
puts

# Check for citations in the response content
# Note: Citations would be in TextContentWithCitations type if present
puts "Content blocks: #{message.content.size}"
message.content.each do |block|
  case block
  when Anthropic::TextContent
    puts "  - TextContent: #{block.text[0..50]}..."
  end
end
puts

# Example 2: Streaming with citations
puts "Example 2: Streaming with citations"
puts "-" * 60

document2 = Anthropic::DocumentContent.text(
  document_text,
  title: "Crystal Language Facts",
  citations: true
)

print "Response: "
citations_found = [] of Anthropic::Citation

client.messages.stream(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    Anthropic::MessageParam.new(
      role: Anthropic::Role::User,
      content: [
        document2,
        Anthropic::TextContent.new("What are the key features of Crystal? List them briefly."),
      ] of Anthropic::ContentBlock
    ),
  ]
) do |event|
  case event
  when Anthropic::ContentBlockDeltaEvent
    # Print text as it streams
    if text = event.text
      print text
      STDOUT.flush
    end

    # Collect citations
    if citation = event.citation
      citations_found << citation
    end
  end
end

puts
puts

if !citations_found.empty?
  puts "Citations found during streaming: #{citations_found.size}"
  citations_found.each_with_index do |citation, i|
    puts "  [#{i + 1}] Document: #{citation.document_title || "untitled"}"
    puts "       Text: \"#{citation.cited_text}\"" if citation.cited_text
    puts "       Position: chars #{citation.start_char}-#{citation.end_char}"
  end
else
  puts "No citations found in streaming response"
end
puts

# Example 3: Multiple documents with citations
puts "Example 3: Multiple documents"
puts "-" * 60

second_document = <<-TEXT
Crystal has excellent tooling support. The crystal command provides:
- crystal build: Compile Crystal programs
- crystal run: Compile and run in one step
- crystal spec: Run test specifications
- crystal tool format: Auto-format code
- crystal docs: Generate documentation

The Crystal ecosystem includes Shards, a dependency manager similar to
Ruby's Bundler. Projects define dependencies in a shard.yml file.
TEXT

doc1 = Anthropic::DocumentContent.text(
  document_text,
  title: "Crystal Overview",
  citations: true
)

doc2 = Anthropic::DocumentContent.text(
  second_document,
  title: "Crystal Tooling",
  citations: true
)

message3 = client.messages.create(
  model: Anthropic::Model::CLAUDE_SONNET_4_5,
  max_tokens: 1024,
  messages: [
    Anthropic::MessageParam.new(
      role: Anthropic::Role::User,
      content: [
        doc1,
        doc2,
        Anthropic::TextContent.new("How do you format Crystal code and what is the dependency manager called?"),
      ] of Anthropic::ContentBlock
    ),
  ]
)

puts "Response:"
message3.text_blocks.each { |block| puts block.text }
puts

puts "=" * 60
puts "Citations provide source attribution for Claude's responses!"
