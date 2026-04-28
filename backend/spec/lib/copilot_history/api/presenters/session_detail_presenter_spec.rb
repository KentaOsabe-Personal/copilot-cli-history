require "rails_helper"

RSpec.describe CopilotHistory::Api::Presenters::SessionDetailPresenter do
  subject(:presenter) { described_class.new }

  describe "#call" do
    it "keeps session issues in the header and groups event issues onto their matching timeline events" do
      session_issue = CopilotHistory::Types::ReadIssue.new(
        code: CopilotHistory::Errors::ReadErrorCode::LEGACY_JSON_PARSE_FAILED,
        message: "legacy session JSON could not be parsed",
        source_path: "/tmp/copilot/history-session-state/legacy-mixed.json",
        severity: :error
      )
      event_issue = CopilotHistory::Types::ReadIssue.new(
        code: CopilotHistory::Errors::ReadErrorCode::EVENT_PARTIAL_MAPPING,
        message: "event payload matched partially",
        source_path: "/tmp/copilot/history-session-state/legacy-mixed.json",
        sequence: 2,
        severity: :warning
      )
      result = CopilotHistory::Api::Types::SessionLookupResult::Found.new(
        root: build_root,
        session: CopilotHistory::Types::NormalizedSession.new(
          session_id: "legacy-mixed",
          source_format: :legacy,
          created_at: "2026-04-26T07:50:00Z",
          updated_at: nil,
          selected_model: "gpt-5.4",
          events: [
            build_event(
              sequence: 1,
              raw_type: "assistant_message",
              occurred_at: "2026-04-26T07:50:01Z",
              role: "assistant",
              content: "legacy mixed event",
              raw_payload: {
                "type" => "assistant_message",
                "role" => "assistant",
                "content" => "legacy mixed event",
                "timestamp" => "2026-04-26T07:50:01Z"
              }
            ),
            build_event(
              sequence: 2,
              mapping_status: :partial,
              raw_type: "assistant_message",
              occurred_at: nil,
              role: "assistant",
              content: "legacy partial event",
              raw_payload: {
                "type" => "assistant_message",
                "role" => "assistant",
                "content" => "legacy partial event"
              }
            )
          ],
          message_snapshots: [
            CopilotHistory::Types::MessageSnapshot.new(
              role: "assistant",
              content: "legacy mixed transcript",
              raw_payload: { "role" => "assistant", "content" => "legacy mixed transcript" }
            )
          ],
          issues: [ session_issue, event_issue ],
          source_paths: {
            source: "/tmp/copilot/history-session-state/legacy-mixed.json"
          }
        )
      )

      expect(presenter.call(result: result)).to eq(
        data: {
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
          degraded: true,
          issues: [
            {
              code: "legacy.json_parse_failed",
              severity: "error",
              message: "legacy session JSON could not be parsed",
              source_path: "/tmp/copilot/history-session-state/legacy-mixed.json",
              scope: "session",
              event_sequence: nil
            }
          ],
          message_snapshots: [
            {
              role: "assistant",
              content: "legacy mixed transcript",
              raw_payload: { "role" => "assistant", "content" => "legacy mixed transcript" }
            }
          ],
          timeline: [
            {
              sequence: 1,
              kind: "message",
              mapping_status: "complete",
              raw_type: "assistant_message",
              occurred_at: "2026-04-26T07:50:01Z",
              role: "assistant",
              content: "legacy mixed event",
              tool_calls: [],
              detail: nil,
              raw_payload: {
                "type" => "assistant_message",
                "role" => "assistant",
                "content" => "legacy mixed event",
                "timestamp" => "2026-04-26T07:50:01Z"
              },
              degraded: false,
              issues: []
            },
            {
              sequence: 2,
              kind: "message",
              mapping_status: "partial",
              raw_type: "assistant_message",
              occurred_at: nil,
              role: "assistant",
              content: "legacy partial event",
              tool_calls: [],
              detail: nil,
              raw_payload: {
                "type" => "assistant_message",
                "role" => "assistant",
                "content" => "legacy partial event"
              },
              degraded: true,
              issues: [
                {
                  code: "event.partial_mapping",
                  severity: "warning",
                  message: "event payload matched partially",
                  source_path: "/tmp/copilot/history-session-state/legacy-mixed.json",
                  scope: "event",
                  event_sequence: 2
                }
              ]
            }
          ]
        }
      )
    end

    it "returns an empty message_snapshots array for current sessions" do
      result = CopilotHistory::Api::Types::SessionLookupResult::Found.new(
        root: build_root,
        session: CopilotHistory::Types::NormalizedSession.new(
          session_id: "current-mixed",
          source_format: :current,
          cwd: "/workspace/current-mixed",
          git_root: "/workspace/current-mixed",
          repository: "octo/example",
          branch: "feature/history",
          created_at: "2026-04-26T10:00:00Z",
          updated_at: "2026-04-26T10:05:00Z",
          selected_model: nil,
          events: [],
          message_snapshots: [],
          issues: [],
          source_paths: {
            workspace: "/tmp/copilot/session-state/current-mixed/workspace.yaml",
            events: "/tmp/copilot/session-state/current-mixed/events.jsonl"
          }
        )
      )

      expect(presenter.call(result: result).dig(:data, :message_snapshots)).to eq([])
    end

    it "maps current timeline helper fields without reinterpreting their backend contract" do
      result = CopilotHistory::Api::Types::SessionLookupResult::Found.new(
        root: build_root,
        session: CopilotHistory::Types::NormalizedSession.new(
          session_id: "current-schema-valid",
          source_format: :current,
          created_at: "2026-04-28T01:00:00Z",
          updated_at: "2026-04-28T01:02:00Z",
          selected_model: nil,
          events: [
            build_event(
              sequence: 1,
              raw_type: "assistant.message",
              occurred_at: "2026-04-28T01:00:04Z",
              role: "assistant",
              content: "I can inspect the latest sessions.",
              tool_calls: [
                CopilotHistory::Types::NormalizedToolCall.new(
                  name: "functions.bash",
                  arguments_preview: "{\"command\":\"git --no-pager status\"}",
                  is_truncated: false,
                  status: :complete
                )
              ]
            ),
            build_event(
              sequence: 2,
              kind: :detail,
              raw_type: "tool.execution_start",
              occurred_at: "2026-04-28T01:00:05Z",
              detail: {
                category: "tool_execution",
                title: "tool.execution_start",
                body: "functions.bash / tool-1"
              },
              raw_payload: {
                "type" => "tool.execution_start"
              }
            )
          ],
          message_snapshots: [],
          issues: [],
          source_paths: {
            workspace: "/tmp/copilot/session-state/current-schema-valid/workspace.yaml",
            events: "/tmp/copilot/session-state/current-schema-valid/events.jsonl"
          }
        )
      )

      expect(presenter.call(result: result).dig(:data, :timeline)).to eq(
        [
          {
            sequence: 1,
            kind: "message",
            mapping_status: "complete",
            raw_type: "assistant.message",
            occurred_at: "2026-04-28T01:00:04Z",
            role: "assistant",
            content: "I can inspect the latest sessions.",
            tool_calls: [
              {
                name: "functions.bash",
                arguments_preview: "{\"command\":\"git --no-pager status\"}",
                is_truncated: false,
                status: "complete"
              }
            ],
            detail: nil,
            raw_payload: nil,
            degraded: false,
            issues: []
          },
          {
            sequence: 2,
            kind: "detail",
            mapping_status: "complete",
            raw_type: "tool.execution_start",
            occurred_at: "2026-04-28T01:00:05Z",
            role: nil,
            content: nil,
            tool_calls: [],
            detail: {
              category: "tool_execution",
              title: "tool.execution_start",
              body: "functions.bash / tool-1"
            },
            raw_payload: {
              "type" => "tool.execution_start"
            },
            degraded: false,
            issues: []
          }
        ]
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

  def build_event(sequence:, raw_type:, occurred_at:, role: nil, content: nil, kind: :message, mapping_status: :complete, tool_calls: [], detail: nil, raw_payload: nil)
    CopilotHistory::Types::NormalizedEvent.new(
      sequence: sequence,
      kind: kind,
      mapping_status: mapping_status,
      raw_type: raw_type,
      occurred_at: occurred_at,
      role: role,
      content: content,
      tool_calls: tool_calls,
      detail: detail,
      raw_payload: raw_payload
    )
  end
end
