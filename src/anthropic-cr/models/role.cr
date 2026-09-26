module Anthropic
  enum Role
    User
    Assistant
    System

    def to_s : String
      super.downcase
    end
  end
end
