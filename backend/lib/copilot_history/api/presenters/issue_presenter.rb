module CopilotHistory
  module Api
    module Presenters
      class IssuePresenter
        def call(issue:)
          {
            code: issue.code,
            severity: issue.severity.to_s,
            message: issue.message,
            source_path: issue.source_path.to_s,
            scope: issue.sequence.nil? ? "session" : "event",
            event_sequence: issue.sequence
          }
        end
      end
    end
  end
end
