module CopilotHistory
  module Api
    module Presenters
      class SessionIndexPresenter
        def initialize(issue_presenter: IssuePresenter.new)
          @issue_presenter = issue_presenter
        end

        def call(result:)
          sessions = result.sessions.map { |session| present_session(session) }

          {
            data: sessions,
            meta: {
              count: sessions.length,
              partial_results: sessions.any? { |session| session[:degraded] }
            }
          }
        end

        private

        attr_reader :issue_presenter

        def present_session(session)
          {
            id: session.session_id,
            source_format: session.source_format.to_s,
            created_at: iso8601_or_nil(session.created_at),
            updated_at: iso8601_or_nil(session.updated_at),
            work_context: work_context_for(session),
            selected_model: session.selected_model,
            event_count: session.events.length,
            message_snapshot_count: session.message_snapshots.length,
            degraded: session.issues.any?,
            issues: session.issues.map { |issue| issue_presenter.call(issue: issue) }
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
