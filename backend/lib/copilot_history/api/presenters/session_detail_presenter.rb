module CopilotHistory
  module Api
    module Presenters
      class SessionDetailPresenter
        def initialize(
          issue_presenter: IssuePresenter.new,
          conversation_projector: CopilotHistory::Projections::ConversationProjector.new,
          activity_projector: CopilotHistory::Projections::ActivityProjector.new
        )
          @issue_presenter = issue_presenter
          @conversation_projector = conversation_projector
          @activity_projector = activity_projector
        end

        def call(result:, include_raw: false)
          session = result.session
          raw_included = include_raw == true
          event_sequences = session.events.map(&:sequence)
          event_issues_by_sequence = session.issues
            .select { |issue| issue.sequence && event_sequences.include?(issue.sequence) }
            .group_by(&:sequence)
          conversation = conversation_projector.call(session)
          activity = activity_projector.call(session)
          conversation_summary = conversation.summary.with(activity_count: activity.entries.length)

          {
            data: {
              id: session.session_id,
              source_format: session.source_format.to_s,
              created_at: iso8601_or_nil(session.created_at),
              updated_at: iso8601_or_nil(session.updated_at),
              work_context: work_context_for(session),
              selected_model: session.selected_model,
              source_state: session.source_state.to_s,
              degraded: session.issues.any?,
              raw_included: raw_included,
              issues: session.issues
                .select { |issue| issue.sequence.nil? || !event_sequences.include?(issue.sequence) }
                .map { |issue| issue_presenter.call(issue: issue) },
              message_snapshots: session.message_snapshots.map { |snapshot| present_snapshot(snapshot, include_raw: raw_included) },
              conversation: present_conversation(conversation, summary: conversation_summary),
              activity: present_activity(
                activity,
                raw_payloads_by_sequence: raw_payloads_by_sequence(session),
                include_raw: raw_included
              ),
              timeline: session.events.map do |event|
                present_event(event, event_issues_by_sequence: event_issues_by_sequence, include_raw: raw_included)
              end
            }
          }
        end

        private

        attr_reader :issue_presenter, :conversation_projector, :activity_projector

        def present_event(event, event_issues_by_sequence:, include_raw:)
          issues = event_issues_by_sequence.fetch(event.sequence, []).map { |issue| issue_presenter.call(issue: issue) }

          {
            sequence: event.sequence,
            kind: event.kind.to_s,
            mapping_status: event.mapping_status.to_s,
            raw_type: event.raw_type,
            occurred_at: iso8601_or_nil(event.occurred_at),
            role: event.role,
            content: event.content,
            tool_calls: event.tool_calls.map { |tool_call| present_tool_call(tool_call) },
            detail: event.detail,
            raw_payload: include_raw ? event.raw_payload : nil,
            degraded: issues.any?,
            issues: issues
          }
        end

        def present_snapshot(snapshot, include_raw:)
          {
            role: snapshot.role,
            content: snapshot.content,
            raw_payload: include_raw ? snapshot.raw_payload : nil
          }
        end

        def present_conversation(conversation, summary:)
          {
            entries: conversation.entries.map { |entry| present_conversation_entry(entry) },
            message_count: conversation.message_count,
            empty_reason: conversation.empty_reason,
            summary: present_conversation_summary(summary)
          }
        end

        def present_conversation_entry(entry)
          {
            sequence: entry.sequence,
            role: entry.role,
            content: entry.content,
            occurred_at: iso8601_or_nil(entry.occurred_at),
            tool_calls: entry.tool_calls.map { |tool_call| present_tool_call(tool_call) },
            degraded: entry.degraded,
            issues: entry.issues.map { |issue| issue_presenter.call(issue: issue) }
          }
        end

        def present_conversation_summary(summary)
          {
            has_conversation: summary.has_conversation,
            message_count: summary.message_count,
            preview: summary.preview,
            activity_count: summary.activity_count
          }
        end

        def present_activity(activity, raw_payloads_by_sequence:, include_raw:)
          {
            entries: activity.entries.map do |entry|
              present_activity_entry(
                entry,
                raw_payload: raw_payloads_by_sequence[entry.sequence],
                include_raw: include_raw
              )
            end
          }
        end

        def present_activity_entry(entry, raw_payload:, include_raw:)
          {
            sequence: entry.sequence,
            category: entry.category,
            title: entry.title,
            summary: entry.summary,
            raw_type: entry.raw_type,
            mapping_status: entry.mapping_status.to_s,
            occurred_at: iso8601_or_nil(entry.occurred_at),
            source_path: path_or_nil(entry.source_path),
            raw_available: entry.raw_available,
            raw_payload: include_raw ? raw_payload : nil,
            degraded: entry.degraded,
            issues: entry.issues.map { |issue| issue_presenter.call(issue: issue) }
          }
        end

        def raw_payloads_by_sequence(session)
          session.events.to_h { |event| [ event.sequence, event.raw_payload ] }
        end

        def work_context_for(session)
          {
            cwd: path_or_nil(session.cwd),
            git_root: path_or_nil(session.git_root),
            repository: session.repository,
            branch: session.branch
          }
        end

        def present_tool_call(tool_call)
          {
            name: tool_call.name,
            arguments_preview: tool_call.arguments_preview,
            is_truncated: tool_call.is_truncated,
            status: tool_call.status.to_s
          }
        end

        def iso8601_or_nil(value)
          value&.iso8601
        end

        def path_or_nil(value)
          value&.to_s
        end
      end
    end
  end
end
