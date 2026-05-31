module Anthropic
  struct BetaWebhookEvent
    include JSON::Serializable

    getter id : String

    @[JSON::Field(key: "created_at")]
    getter created_at : String

    getter type : String = "event"
    getter data : JSON::Any
  end

  alias UnwrapWebhookEvent = BetaWebhookEvent
end
