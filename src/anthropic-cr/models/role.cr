module Anthropic
  enum Role
    User
    Assistant

    def to_s : String
      super.downcase
    end
  end
end
