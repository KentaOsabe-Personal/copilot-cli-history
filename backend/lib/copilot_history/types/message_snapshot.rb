module CopilotHistory
  module Types
    class MessageSnapshot < Data.define(:role, :content, :raw_payload)
      def initialize(role:, content:, raw_payload:)
        super(role:, content:, raw_payload:)
      end
    end
  end
end
