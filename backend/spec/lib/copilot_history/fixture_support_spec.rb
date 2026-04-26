require "rails_helper"

RSpec.describe "Copilot history fixture support", :copilot_history do
  it "provides raw current and legacy fixture files from a mixed root" do
    with_copilot_history_fixture("mixed_root") do |root|
      workspace = root.join("session-state/current-mixed/workspace.yaml")
      events = root.join("session-state/current-mixed/events.jsonl")
      legacy = root.join("history-session-state/legacy-mixed.json")

      expect(workspace.read).to include("session_id: current-mixed")
      expect(events.each_line.map(&:strip)).to include(
        a_string_including("\"type\":\"user_message\""),
        a_string_including("\"type\":\"mystery-event\"")
      )
      expect(legacy.read).to include("\"sessionId\": \"legacy-mixed\"")
    end
  end

  it "can apply and restore permission restrictions on copied fixture artifacts" do
    with_copilot_history_fixture("current_unreadable") do |root|
      target = root.join("session-state/current-unreadable/events.jsonl")
      original_mode = target.stat.mode & 0o777

      with_permission_denied(target) do |restricted_path|
        expect(restricted_path.stat.mode & 0o777).to eq(0o000)
      end

      expect(target.stat.mode & 0o777).to eq(original_mode)
    end
  end
end
