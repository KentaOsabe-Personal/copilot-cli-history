module CopilotHistory
  module Api
    module Presenters
      class SessionDetailPresenter
        def initialize(issue_presenter: IssuePresenter.new)
          @issue_presenter = issue_presenter
        end

        def call(result:)
          session = result.session
          event_issues_by_sequence = session.issues.select { |issue| issue.sequence }.group_by(&:sequence)

          {
            data: {
              id: session.session_id,
              source_format: session.source_format.to_s,
              created_at: iso8601_or_nil(session.created_at),
              updated_at: iso8601_or_nil(session.updated_at),
              work_context: work_context_for(session),
              selected_model: session.selected_model,
              degraded: session.issues.any?,
              issues: session.issues.select { |issue| issue.sequence.nil? }.map { |issue| issue_presenter.call(issue: issue) },
              message_snapshots: session.message_snapshots.map { |snapshot| present_snapshot(snapshot) },
              timeline: session.events.map { |event| present_event(event, event_issues_by_sequence: event_issues_by_sequence) }
            }
          }
        end

        private

        attr_reader :issue_presenter

        def present_event(event, event_issues_by_sequence:)
          issues = event_issues_by_sequence.fetch(event.sequence, []).map { |issue| issue_presenter.call(issue: issue) }

          {
            sequence: event.sequence,
            kind: event.kind.to_s,
            raw_type: event.raw_type,
            occurred_at: iso8601_or_nil(event.occurred_at),
            role: event.role,
            content: event.content,
            raw_payload: event.raw_payload,
            degraded: issues.any?,
            issues: issues
          }
        end

        def present_snapshot(snapshot)
          {
            role: snapshot.role,
            content: snapshot.content,
            raw_payload: snapshot.raw_payload
          }
        end

        def work_context_for(session)
          {
            cwd: path_or_nil(session.cwd),
            git_root: path_or_nil(session.git_root),
            repository: session.repository,
            branch: session.branch
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
