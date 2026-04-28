module CopilotHistory
  module Types
    class ConversationProjection < Data.define(:entries, :message_count, :empty_reason, :summary)
      VALID_EMPTY_REASONS = %w[no_events no_conversation_messages events_unavailable].freeze

      def initialize(entries:, empty_reason:, summary:)
        normalized_empty_reason = normalize_empty_reason(empty_reason)

        super(
          entries: entries.freeze,
          message_count: entries.length,
          empty_reason: normalized_empty_reason,
          summary: summary
        )
      end

      private

      def normalize_empty_reason(value)
        return nil if value.nil?

        normalized_value = value.to_s
        unless VALID_EMPTY_REASONS.include?(normalized_value)
          raise ArgumentError, "empty_reason must be one of: #{VALID_EMPTY_REASONS.join(", ")}"
        end

        normalized_value
      end
    end
  end
end
