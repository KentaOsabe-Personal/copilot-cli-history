require "rails_helper"

RSpec.describe CopilotHistory::Api::Types::SessionLookupResult do
  describe "public states" do
    it "only exposes found and not found states for detail lookup" do
      expect(described_class.constants(false)).to contain_exactly(:Found, :NotFound)
    end
  end

  describe described_class::Found do
    it "wraps resolved root and normalized session in the public found envelope" do
      root = CopilotHistory::Types::ResolvedHistoryRoot.new(
        root_path: "/tmp/copilot",
        current_root: "/tmp/copilot/session-state",
        legacy_root: "/tmp/copilot/history-session-state"
      )
      session = CopilotHistory::Types::NormalizedSession.new(
        session_id: "session-123",
        source_format: :current,
        created_at: "2026-04-26T10:00:00Z",
        updated_at: "2026-04-26T10:05:00Z",
        selected_model: "gpt-5.4",
        events: [],
        message_snapshots: [],
        issues: [],
        source_paths: {
          workspace: "/tmp/copilot/session-state/session-123/workspace.yaml",
          events: "/tmp/copilot/session-state/session-123/events.jsonl"
        }
      )

      result = described_class.new(root:, session:)

      expect(described_class.members).to eq(%i[root session])
      expect(result.root).to eq(root)
      expect(result.session).to eq(session)
    end
  end

  describe described_class::NotFound do
    it "retains only the requested session id in the public miss envelope" do
      result = described_class.new(session_id: "session-123")

      expect(described_class.members).to eq([ :session_id ])
      expect(result.session_id).to eq("session-123")
    end
  end
end
