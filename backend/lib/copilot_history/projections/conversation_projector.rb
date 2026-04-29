module CopilotHistory
  module Projections
    class ConversationProjector
      PREVIEW_LIMIT = 140

      def call(session)
        issues_by_sequence = event_issues_by_sequence(session)
        entries = conversation_events(session).map do |event|
          issues = issues_by_sequence.fetch(event.sequence, [])

          CopilotHistory::Types::NormalizedConversationEntry.new(
            sequence: event.sequence,
            role: event.role,
            content: event.content,
            occurred_at: event.occurred_at,
            tool_calls: event.tool_calls,
            degraded: issues.any?,
            issues: issues
          )
        end

        CopilotHistory::Types::ConversationProjection.new(
          entries: entries,
          empty_reason: empty_reason_for(session:, entries: entries),
          summary: CopilotHistory::Types::ConversationSummary.new(
            has_conversation: entries.any?,
            message_count: entries.length,
            preview: preview_for(entries)
          )
        )
      end

      private

      def conversation_events(session)
        session.events
          .select { |event| conversation_event?(event) }
          .sort_by(&:sequence)
      end

      def conversation_event?(event)
        event.kind == :message &&
          %w[user assistant].include?(event.role.to_s) &&
          present?(event.content)
      end

      def empty_reason_for(session:, entries:)
        return nil if entries.any?
        return "events_unavailable" if session.events.empty? && events_unavailable?(session)
        return "no_events" if session.events.empty?

        "no_conversation_messages"
      end

      def events_unavailable?(session)
        unavailable_codes = [
          CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENTS_UNREADABLE,
          CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENT_PARSE_FAILED
        ]

        session.issues.any? { |issue| unavailable_codes.include?(issue.code) }
      end

      def preview_for(entries)
        content = entries.first&.content
        return nil unless present?(content)
        return content if content.length <= PREVIEW_LIMIT

        content[0, PREVIEW_LIMIT]
      end

      def event_issues_by_sequence(session)
        session.issues
          .select(&:sequence)
          .group_by(&:sequence)
      end

      def present?(value)
        !value.nil? && !value.to_s.empty?
      end
    end
  end
end
