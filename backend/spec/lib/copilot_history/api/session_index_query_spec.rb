require "rails_helper"

RSpec.describe CopilotHistory::Api::SessionIndexQuery do
  subject(:query) { described_class.new(session_catalog_reader: session_catalog_reader) }

  let(:session_catalog_reader) { instance_double(CopilotHistory::SessionCatalogReader) }

  describe "#call" do
    it "returns root failures from the reader without changing the public result shape" do
      failure_result = CopilotHistory::Types::ReadResult::Failure.new(
        failure: CopilotHistory::Types::ReadFailure.new(
          code: CopilotHistory::Errors::ReadErrorCode::ROOT_MISSING,
          path: "/tmp/copilot",
          message: "history root does not exist"
        )
      )

      expect(session_catalog_reader).to receive(:call).once.and_return(failure_result)

      expect(query.call).to eq(failure_result)
    end

    it "sorts mixed current and legacy sessions deterministically while preserving issues" do
      issue = CopilotHistory::Types::ReadIssue.new(
        code: CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_PARSE_FAILED,
        message: "workspace.yaml could not be parsed",
        source_path: "/tmp/copilot/session-state/same-b/workspace.yaml",
        severity: :error
      )
      root = CopilotHistory::Types::ResolvedHistoryRoot.new(
        root_path: "/tmp/copilot",
        current_root: "/tmp/copilot/session-state",
        legacy_root: "/tmp/copilot/history-session-state"
      )
      success_result = CopilotHistory::Types::ReadResult::Success.new(
        root: root,
        sessions: [
          build_session(session_id: "epoch", source_format: :legacy),
          build_session(session_id: "same-b", source_format: :current, created_at: "2026-04-26T09:00:00Z", issues: [ issue ]),
          build_session(session_id: "latest", source_format: :current, updated_at: "2026-04-26T10:00:00Z"),
          build_session(session_id: "same-a", source_format: :legacy, created_at: "2026-04-26T09:00:00Z")
        ]
      )

      expect(session_catalog_reader).to receive(:call).once.and_return(success_result)

      result = query.call

      expect(result).to be_a(CopilotHistory::Types::ReadResult::Success)
      expect(result.root).to eq(root)
      expect(result.sessions.map(&:session_id)).to eq(%w[latest same-a same-b epoch])
      expect(result.sessions.find { |session| session.session_id == "same-b" }.issues).to eq([ issue ])
    end
  end

  def build_session(session_id:, source_format:, created_at: nil, updated_at: nil, issues: [])
    CopilotHistory::Types::NormalizedSession.new(
      session_id: session_id,
      source_format: source_format,
      created_at: created_at,
      updated_at: updated_at,
      selected_model: nil,
      events: [],
      message_snapshots: [],
      issues: issues,
      source_paths: {
        source: "/tmp/copilot/#{session_id}.json"
      }
    )
  end
end
