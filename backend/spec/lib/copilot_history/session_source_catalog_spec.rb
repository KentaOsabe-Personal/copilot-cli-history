require "rails_helper"

RSpec.describe CopilotHistory::SessionSourceCatalog, :copilot_history do
  describe "#call" do
    it "enumerates current session directories as source descriptors" do
      with_copilot_history_fixture("current_valid") do |root|
        resolved_root = CopilotHistory::Types::ResolvedHistoryRoot.new(
          root_path: root,
          current_root: root.join("session-state"),
          legacy_root: root.join("history-session-state")
        )

        sources = described_class.new.call(resolved_root)

        expect(sources).to eq(
          [
            CopilotHistory::Types::SessionSource.new(
              format: :current,
              session_id: "current-valid",
              source_path: root.join("session-state/current-valid"),
              artifact_paths: {
                workspace: root.join("session-state/current-valid/workspace.yaml"),
                events: root.join("session-state/current-valid/events.jsonl")
              }
            )
          ]
        )
      end
    end

    it "enumerates legacy session files as source descriptors" do
      with_copilot_history_fixture("legacy_valid") do |root|
        resolved_root = CopilotHistory::Types::ResolvedHistoryRoot.new(
          root_path: root,
          current_root: root.join("session-state"),
          legacy_root: root.join("history-session-state")
        )

        sources = described_class.new.call(resolved_root)

        expect(sources).to eq(
          [
            CopilotHistory::Types::SessionSource.new(
              format: :legacy,
              session_id: "legacy-valid",
              source_path: root.join("history-session-state/legacy-valid.json"),
              artifact_paths: {
                source: root.join("history-session-state/legacy-valid.json")
              }
            )
          ]
        )
      end
    end

    it "returns both current and legacy sources in a stable order for mixed roots" do
      with_copilot_history_fixture("mixed_root") do |root|
        resolved_root = CopilotHistory::Types::ResolvedHistoryRoot.new(
          root_path: root,
          current_root: root.join("session-state"),
          legacy_root: root.join("history-session-state")
        )

        sources = described_class.new.call(resolved_root)

        expect(sources.map(&:format)).to eq(%i[current legacy])
        expect(sources.map(&:session_id)).to eq(%w[current-mixed legacy-mixed])
        expect(sources.map(&:source_path)).to eq(
          [
            root.join("session-state/current-mixed"),
            root.join("history-session-state/legacy-mixed.json")
          ]
        )
      end
    end
  end
end
