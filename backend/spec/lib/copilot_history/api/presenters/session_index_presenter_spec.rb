require "rails_helper"

RSpec.describe CopilotHistory::Api::Presenters::SessionIndexPresenter do
  subject(:presenter) { described_class.new }

  describe "#call" do
    it "maps mixed current and legacy sessions to the shared summary schema with partial_results metadata" do
      event_issue = CopilotHistory::Types::ReadIssue.new(
        code: CopilotHistory::Errors::ReadErrorCode::EVENT_UNKNOWN_SHAPE,
        message: "event payload could not be mapped to canonical fields",
        source_path: "/tmp/copilot/session-state/current-mixed/events.jsonl",
        sequence: 2,
        severity: :warning
      )
      result = CopilotHistory::Types::ReadResult::Success.new(
        root: build_root,
        sessions: [
          CopilotHistory::Types::NormalizedSession.new(
            session_id: "current-mixed",
            source_format: :current,
            source_state: :degraded,
            cwd: "/workspace/current-mixed",
            git_root: "/workspace/current-mixed",
            repository: "octo/example",
            branch: "feature/history",
            created_at: "2026-04-26T10:00:00Z",
            updated_at: "2026-04-26T10:05:00Z",
            selected_model: nil,
            events: [
              build_event(sequence: 1, raw_type: "user_message", occurred_at: "2026-04-26T10:00:01Z", role: "user", content: "current"),
              build_event(sequence: 2, kind: :unknown, raw_type: "mystery-event", occurred_at: "2026-04-26T10:00:02Z", raw_payload: { "value" => 42 })
            ],
            message_snapshots: [],
            issues: [ event_issue ],
            source_paths: {
              workspace: "/tmp/copilot/session-state/current-mixed/workspace.yaml",
              events: "/tmp/copilot/session-state/current-mixed/events.jsonl"
            }
          ),
          CopilotHistory::Types::NormalizedSession.new(
            session_id: "legacy-mixed",
            source_format: :legacy,
            created_at: "2026-04-26T07:50:00Z",
            updated_at: nil,
            selected_model: "gpt-5.4",
            events: [ build_event(sequence: 1, raw_type: "assistant_message", occurred_at: "2026-04-26T07:50:01Z", role: "assistant", content: "legacy") ],
            message_snapshots: [
              CopilotHistory::Types::MessageSnapshot.new(
                role: "assistant",
                content: "legacy mixed transcript",
                raw_payload: { "role" => "assistant", "content" => "legacy mixed transcript" }
              )
            ],
            issues: [],
            source_paths: {
              source: "/tmp/copilot/history-session-state/legacy-mixed.json"
            }
          )
        ]
      )

      expect(presenter.call(result: result)).to eq(
        data: [
          {
            id: "current-mixed",
            source_format: "current",
            created_at: "2026-04-26T10:00:00Z",
            updated_at: "2026-04-26T10:05:00Z",
            work_context: {
              cwd: "/workspace/current-mixed",
              git_root: "/workspace/current-mixed",
              repository: "octo/example",
              branch: "feature/history"
            },
            selected_model: nil,
            source_state: "degraded",
            event_count: 2,
            message_snapshot_count: 0,
            conversation_summary: {
              has_conversation: true,
              message_count: 1,
              preview: "current",
              activity_count: 1
            },
            degraded: true,
            issues: [
              {
                code: "event.unknown_shape",
                severity: "warning",
                message: "event payload could not be mapped to canonical fields",
                source_path: "/tmp/copilot/session-state/current-mixed/events.jsonl",
                scope: "event",
                event_sequence: 2
              }
            ]
          },
          {
            id: "legacy-mixed",
            source_format: "legacy",
            created_at: "2026-04-26T07:50:00Z",
            updated_at: nil,
            work_context: {
              cwd: nil,
              git_root: nil,
              repository: nil,
              branch: nil
            },
            selected_model: "gpt-5.4",
            source_state: "complete",
            event_count: 1,
            message_snapshot_count: 1,
            conversation_summary: {
              has_conversation: true,
              message_count: 1,
              preview: "legacy",
              activity_count: 0
            },
            degraded: false,
            issues: []
          }
        ],
        meta: {
          count: 2,
          partial_results: true
        }
      )
    end
  end

  def build_root
    CopilotHistory::Types::ResolvedHistoryRoot.new(
      root_path: "/tmp/copilot",
      current_root: "/tmp/copilot/session-state",
      legacy_root: "/tmp/copilot/history-session-state"
    )
  end

  def build_event(sequence:, raw_type:, occurred_at:, role: nil, content: nil, kind: :message, raw_payload: nil)
    CopilotHistory::Types::NormalizedEvent.new(
      sequence: sequence,
      kind: kind,
      mapping_status: kind == :unknown ? :partial : :complete,
      raw_type: raw_type,
      occurred_at: occurred_at,
      role: role,
      content: content,
      raw_payload: raw_payload
    )
  end
end
