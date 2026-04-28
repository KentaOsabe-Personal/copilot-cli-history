module CopilotHistory
  module Projections
    class ActivityProjector
      def call(session)
        issues_by_sequence = event_issues_by_sequence(session)
        entries = activity_events(session).map do |event|
          issues = issues_by_sequence.fetch(event.sequence, [])

          CopilotHistory::Types::NormalizedActivityEntry.new(
            sequence: event.sequence,
            category: category_for(event),
            title: title_for(event),
            summary: summary_for(event),
            raw_type: event.raw_type,
            mapping_status: event.mapping_status,
            occurred_at: event.occurred_at,
            source_path: source_path_for(session),
            raw_available: !event.raw_payload.nil?,
            degraded: issues.any?,
            issues: issues
          )
        end

        CopilotHistory::Types::ActivityProjection.new(entries: entries)
      end

      private

      def activity_events(session)
        session.events
          .select { |event| activity_event?(event) }
          .sort_by(&:sequence)
      end

      def activity_event?(event)
        event.kind == :detail ||
          event.kind == :unknown ||
          (event.kind == :message && event.role.to_s == "system")
      end

      def category_for(event)
        return "system" if event.kind == :message && event.role.to_s == "system"
        return "unknown" if event.kind == :unknown

        event.detail&.fetch(:category, nil) || event.kind.to_s
      end

      def title_for(event)
        event.detail&.fetch(:title, nil) || event.raw_type
      end

      def summary_for(event)
        return event.content if event.kind == :message

        event.detail&.fetch(:body, nil)
      end

      def source_path_for(session)
        session.source_paths[:events] || session.source_paths[:source] || session.source_paths.values.first
      end

      def event_issues_by_sequence(session)
        session.issues
          .select(&:sequence)
          .group_by(&:sequence)
      end
    end
  end
end
