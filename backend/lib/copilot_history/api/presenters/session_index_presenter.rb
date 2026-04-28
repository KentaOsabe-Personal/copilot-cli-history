module CopilotHistory
  module Api
    module Presenters
      class SessionIndexPresenter
        def initialize(
          issue_presenter: IssuePresenter.new,
          conversation_projector: CopilotHistory::Projections::ConversationProjector.new,
          activity_projector: CopilotHistory::Projections::ActivityProjector.new
        )
          @issue_presenter = issue_presenter
          @conversation_projector = conversation_projector
          @activity_projector = activity_projector
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

        attr_reader :issue_presenter, :conversation_projector, :activity_projector

        def present_session(session)
          conversation = conversation_projector.call(session)
          activity = activity_projector.call(session)
          conversation_summary = conversation.summary.with(activity_count: activity.entries.length)

          {
            id: session.session_id,
            source_format: session.source_format.to_s,
            created_at: iso8601_or_nil(session.created_at),
            updated_at: iso8601_or_nil(session.updated_at),
            work_context: work_context_for(session),
            selected_model: session.selected_model,
            source_state: session.source_state.to_s,
            event_count: session.events.length,
            message_snapshot_count: session.message_snapshots.length,
            conversation_summary: present_conversation_summary(conversation_summary),
            degraded: session.issues.any?,
            issues: session.issues.map { |issue| issue_presenter.call(issue: issue) }
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
