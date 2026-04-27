require "rails_helper"

RSpec.describe CopilotHistory::Api::Presenters::IssuePresenter do
  describe "#call" do
    subject(:presenter) { described_class.new }

    it "maps session-level issues to the shared JSON-compatible payload" do
      issue = CopilotHistory::Types::ReadIssue.new(
        code: CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_PARSE_FAILED,
        message: "workspace.yaml could not be parsed",
        source_path: "/tmp/copilot/workspace.yaml",
        severity: :error
      )

      expect(presenter.call(issue:)).to eq(
        code: "current.workspace_parse_failed",
        severity: "error",
        message: "workspace.yaml could not be parsed",
        source_path: "/tmp/copilot/workspace.yaml",
        scope: "session",
        event_sequence: nil
      )
    end

    it "maps event-level issues to the same payload with event location fields" do
      issue = CopilotHistory::Types::ReadIssue.new(
        code: CopilotHistory::Errors::ReadErrorCode::EVENT_PARTIAL_MAPPING,
        message: "event payload matched partially",
        source_path: "/tmp/copilot/events.jsonl",
        sequence: 7,
        severity: :warning
      )

      expect(presenter.call(issue:)).to eq(
        code: "event.partial_mapping",
        severity: "warning",
        message: "event payload matched partially",
        source_path: "/tmp/copilot/events.jsonl",
        scope: "event",
        event_sequence: 7
      )
    end
  end
end
