module CopilotHistory
  module Types
    class ConversationSummary < Data.define(:has_conversation, :message_count, :preview, :activity_count)
      def initialize(has_conversation:, message_count:, preview:, activity_count: 0)
        super(
          has_conversation: !!has_conversation,
          message_count: Integer(message_count),
          preview: presence(preview),
          activity_count: Integer(activity_count)
        )
      end

      private

      def presence(value)
        return nil if value.nil?

        string_value = value.to_s
        string_value.empty? ? nil : string_value
      end
    end
  end
end
