require "rails_helper"

RSpec.describe CopilotHistory::Api::SessionDetailQuery do
  subject(:query) { described_class.new(session_catalog_reader: session_catalog_reader) }

  let(:session_catalog_reader) { instance_double(CopilotHistory::SessionCatalogReader) }
  let(:root) do
    CopilotHistory::Types::ResolvedHistoryRoot.new(
      root_path: "/tmp/copilot",
      current_root: "/tmp/copilot/session-state",
      legacy_root: "/tmp/copilot/history-session-state"
    )
  end

  describe "#call" do
    it "returns a found result for an exact session_id match without adding HTTP concerns" do
      matched_session = build_session(session_id: "session-123", source_format: :current)
      success_result = CopilotHistory::Types::ReadResult::Success.new(
        root: root,
        sessions: [
          build_session(session_id: "session-12", source_format: :legacy),
          matched_session
        ]
      )

      expect(session_catalog_reader).to receive(:call).once.and_return(success_result)

      result = query.call(session_id: "session-123")

      expect(result).to eq(
        CopilotHistory::Api::Types::SessionLookupResult::Found.new(
          root: root,
          session: matched_session
        )
      )
      expect(result).not_to respond_to(:status)
    end

    it "returns not_found when the readable root does not include the requested session id" do
      success_result = CopilotHistory::Types::ReadResult::Success.new(
        root: root,
        sessions: [ build_session(session_id: "session-123", source_format: :current) ]
      )

      expect(session_catalog_reader).to receive(:call).once.and_return(success_result)

      expect(query.call(session_id: "missing-session")).to eq(
        CopilotHistory::Api::Types::SessionLookupResult::NotFound.new(session_id: "missing-session")
      )
    end

    it "returns root failures from the reader unchanged" do
      failure_result = CopilotHistory::Types::ReadResult::Failure.new(
        failure: CopilotHistory::Types::ReadFailure.new(
          code: CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED,
          path: "/tmp/copilot",
          message: "history root is not accessible"
        )
      )

      expect(session_catalog_reader).to receive(:call).once.and_return(failure_result)

      expect(query.call(session_id: "session-123")).to eq(failure_result)
    end
  end

  def build_session(session_id:, source_format:)
    CopilotHistory::Types::NormalizedSession.new(
      session_id: session_id,
      source_format: source_format,
      created_at: "2026-04-26T10:00:00Z",
      updated_at: "2026-04-26T10:05:00Z",
      selected_model: nil,
      events: [],
      message_snapshots: [],
      issues: [],
      source_paths: {
        source: "/tmp/copilot/#{session_id}.json"
      }
    )
  end
end
