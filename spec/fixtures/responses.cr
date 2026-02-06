# Test fixtures for API responses
#
# These are static JSON strings that represent typical API responses.
# Used with WebMock to stub HTTP responses in unit tests.

module Fixtures
  module Responses
    # Message API responses
    MESSAGE_BASIC = %({"id":"msg_01XFDUDYJgAACzvnptvVoYEL","type":"message","role":"assistant","content":[{"type":"text","text":"Hello! I'm Claude, an AI assistant."}],"model":"claude-sonnet-4-5-20250929","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":15}})

    MESSAGE_WITH_TOOL_USE = %({"id":"msg_01abc123","type":"message","role":"assistant","content":[{"type":"text","text":"I'll check the weather for you."},{"type":"tool_use","id":"toolu_01xyz","name":"get_weather","input":{"location":"San Francisco","unit":"fahrenheit"}}],"model":"claude-sonnet-4-5-20250929","stop_reason":"tool_use","stop_sequence":null,"usage":{"input_tokens":50,"output_tokens":80}})

    MESSAGE_WITH_THINKING = %({"id":"msg_thinking_01","type":"message","role":"assistant","content":[{"type":"thinking","thinking":"Let me think about this carefully...","signature":"sig123"},{"type":"text","text":"After consideration, here is my answer."}],"model":"claude-sonnet-4-5-20250929","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":20,"output_tokens":40,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}})

    MESSAGE_OPUS_46 = %({"id":"msg_opus46_01","type":"message","role":"assistant","content":[{"type":"thinking","thinking":"Adaptive thinking in action...","signature":"sig456"},{"type":"text","text":"Hello from Opus 4.6!"}],"model":"claude-opus-4-6","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":15,"output_tokens":25}})

    # Model API responses
    MODEL_INFO = %({"type":"model","id":"claude-sonnet-4-5-20250929","display_name":"Claude Sonnet 4.5","created_at":"2025-09-29T00:00:00Z"})

    MODEL_LIST = %({"data":[{"type":"model","id":"claude-sonnet-4-5-20250929","display_name":"Claude Sonnet 4.5","created_at":"2025-09-29T00:00:00Z"},{"type":"model","id":"claude-haiku-4-5-20251001","display_name":"Claude Haiku 4.5","created_at":"2025-10-01T00:00:00Z"}],"has_more":false,"first_id":"claude-sonnet-4-5-20250929","last_id":"claude-haiku-4-5-20251001"})

    MODEL_LIST_WITH_MORE = %({"data":[{"type":"model","id":"model1","display_name":"Model 1","created_at":"2025-01-01T00:00:00Z"}],"has_more":true,"first_id":"model1","last_id":"model1"})

    # Batch API responses
    BATCH_CREATED = %({"id":"msgbatch_01abc","type":"message_batch","processing_status":"in_progress","request_counts":{"processing":2,"succeeded":0,"errored":0,"canceled":0,"expired":0},"ended_at":null,"created_at":"2025-01-01T00:00:00Z","expires_at":"2025-01-02T00:00:00Z","cancel_initiated_at":null,"results_url":null})

    BATCH_COMPLETED = %({"id":"msgbatch_01abc","type":"message_batch","processing_status":"ended","request_counts":{"processing":0,"succeeded":2,"errored":0,"canceled":0,"expired":0},"ended_at":"2025-01-01T01:00:00Z","created_at":"2025-01-01T00:00:00Z","expires_at":"2025-01-02T00:00:00Z","cancel_initiated_at":null,"results_url":"https://api.anthropic.com/v1/messages/batches/msgbatch_01abc/results"})

    BATCH_LIST = %({"data":[{"id":"msgbatch_01abc","type":"message_batch","processing_status":"ended","request_counts":{"processing":0,"succeeded":2,"errored":0,"canceled":0,"expired":0},"ended_at":"2025-01-01T01:00:00Z","created_at":"2025-01-01T00:00:00Z","expires_at":"2025-01-02T00:00:00Z","cancel_initiated_at":null,"results_url":null}],"has_more":false,"first_id":"msgbatch_01abc","last_id":"msgbatch_01abc"})

    BATCH_RESULT_LINE = %({"custom_id":"req-1","result":{"type":"succeeded","message":{"id":"msg_01abc","type":"message","role":"assistant","content":[{"type":"text","text":"4"}],"model":"claude-haiku-4-5-20251001","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":5}}}})

    # File API responses
    FILE_METADATA = %({"id":"file_01abc123","type":"file","filename":"document.pdf","mime_type":"application/pdf","size_bytes":1024000,"created_at":"2025-01-01T00:00:00Z","downloadable":false})

    FILE_LIST = %({"data":[{"id":"file_01abc123","type":"file","filename":"document.pdf","mime_type":"application/pdf","size_bytes":1024000,"created_at":"2025-01-01T00:00:00Z","downloadable":false},{"id":"file_02xyz456","type":"file","filename":"image.png","mime_type":"image/png","size_bytes":50000,"created_at":"2025-01-01T01:00:00Z","downloadable":false}],"has_more":false,"first_id":"file_01abc123","last_id":"file_02xyz456"})

    FILE_DELETED = %({"id":"file_01abc123","type":"file_deleted"})

    # Token counting responses
    TOKEN_COUNT_BASIC = %({"input_tokens":25})

    TOKEN_COUNT_WITH_CACHE = %({"input_tokens":1500,"cache_creation_input_tokens":1200,"cache_read_input_tokens":0})

    TOKEN_COUNT_CACHE_HIT = %({"input_tokens":1500,"cache_creation_input_tokens":0,"cache_read_input_tokens":1200})

    # Error responses
    ERROR_BAD_REQUEST = %({"type":"error","error":{"type":"invalid_request_error","message":"Invalid request: missing required field 'messages'"}})

    ERROR_UNAUTHORIZED = %({"type":"error","error":{"type":"authentication_error","message":"Invalid API key provided"}})

    ERROR_NOT_FOUND = %({"type":"error","error":{"type":"not_found_error","message":"The requested resource was not found"}})

    ERROR_RATE_LIMIT = %({"type":"error","error":{"type":"rate_limit_error","message":"Rate limit exceeded. Please retry after 30 seconds."}})

    ERROR_SERVER = %({"type":"error","error":{"type":"api_error","message":"Internal server error"}})

    # Streaming event fixtures
    module Streaming
      MESSAGE_START = %(data: {"type":"message_start","message":{"id":"msg_stream_01","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5-20250929","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}})

      CONTENT_BLOCK_START = %(data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})

      CONTENT_BLOCK_DELTA_TEXT = %(data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}})

      CONTENT_BLOCK_DELTA_THINKING = %(data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Let me think..."}})

      CONTENT_BLOCK_DELTA_JSON = %(data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"loc"}})

      CONTENT_BLOCK_STOP = %(data: {"type":"content_block_stop","index":0})

      MESSAGE_DELTA = %(data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}})

      MESSAGE_STOP = %(data: {"type":"message_stop"})

      PING = %(data: {"type":"ping"})

      # Full streaming sequence
      FULL_TEXT_STREAM = [
        MESSAGE_START,
        CONTENT_BLOCK_START,
        %(data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}),
        %(data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}),
        %(data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"!"}}),
        CONTENT_BLOCK_STOP,
        MESSAGE_DELTA,
        MESSAGE_STOP,
      ].join("\n\n")
    end
  end
end
