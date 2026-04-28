require "rails_helper"

RSpec.describe "API Sessions", :copilot_history, type: :request do
  around do |example|
    original_copilot_home = ENV["COPILOT_HOME"]
    original_home = ENV["HOME"]

    example.run
  ensure
    ENV["COPILOT_HOME"] = original_copilot_home
    ENV["HOME"] = original_home
  end

  before do
    host! "localhost"
  end

  describe "GET /api/sessions" do
    it "returns mixed current and legacy sessions in the shared summary schema with deterministic order" do
      with_copilot_history_fixture("mixed_root") do |root|
        events_path = root.join("session-state/current-mixed/events.jsonl")
        ENV["COPILOT_HOME"] = root.to_s
        events_path.write(<<~JSONL)
          {"type":"user_message","role":"user","content":"mixed root current session","timestamp":"2026-04-26T10:00:01Z"}
          {"type":"assistant_message","role":"assistant","content":"current follow up","timestamp":"2026-04-26T10:00:02Z"}
        JSONL

        get "/api/sessions"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(
          data: [
            {
              id: "current-mixed",
              source_format: "current",
              created_at: "2026-04-26T10:00:00Z",
              updated_at: "2026-04-26T10:00:02Z",
              work_context: {
                cwd: "/workspace/current-mixed",
                git_root: "/workspace/current-mixed",
                repository: "octo/example",
                branch: "feature/history"
              },
              selected_model: nil,
              event_count: 2,
              message_snapshot_count: 0,
              degraded: false,
              issues: []
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
              event_count: 1,
              message_snapshot_count: 1,
              degraded: false,
              issues: []
            }
          ],
          meta: {
            count: 2,
            partial_results: false
          }
        )
      end
    end

    it "keeps session-scoped degradation in a 200 response instead of promoting it to a root failure" do
      with_copilot_history_fixture("mixed_root") do |root|
        events_path = root.join("session-state/current-mixed/events.jsonl")
        workspace_path = root.join("session-state/current-mixed/workspace.yaml")
        ENV["COPILOT_HOME"] = root.to_s
        events_path.write(<<~JSONL)
          {"type":"user_message","role":"user","content":"mixed root current session","timestamp":"2026-04-26T10:00:01Z"}
          {"type":"assistant_message","role":"assistant","content":"current follow up","timestamp":"2026-04-26T10:00:02Z"}
        JSONL

        with_permission_denied(workspace_path) do
          get "/api/sessions"

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body, symbolize_names: true)).to eq(
            data: [
              {
                id: "current-mixed",
                source_format: "current",
                created_at: nil,
                updated_at: "2026-04-26T10:00:02Z",
                work_context: {
                  cwd: nil,
                  git_root: nil,
                  repository: nil,
                  branch: nil
                },
                selected_model: nil,
                event_count: 2,
                message_snapshot_count: 0,
                degraded: true,
                issues: [
                  {
                    code: "current.workspace_unreadable",
                    severity: "error",
                    message: "workspace.yaml is not accessible",
                    source_path: workspace_path.to_s,
                    scope: "session",
                    event_sequence: nil
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
                event_count: 1,
                message_snapshot_count: 1,
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
    end

    it "returns the shared 503 error envelope for root failures instead of an empty list" do
      Dir.mktmpdir("copilot-history-home") do |home|
        ENV.delete("COPILOT_HOME")
        ENV["HOME"] = home

        get "/api/sessions"

        expect(response).to have_http_status(:service_unavailable)
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(
          error: {
            code: "root_missing",
            message: "history root does not exist",
            details: {
              path: File.join(home, ".copilot")
            }
          }
        )
      end
    end
  end

  describe "GET /api/sessions/:id" do
    it "returns header, message snapshots, and timeline in a single read-only response" do
      with_copilot_history_fixture("mixed_root") do |root|
        legacy_path = root.join("history-session-state/legacy-mixed.json")
        legacy_payload = JSON.parse(legacy_path.read)
        ENV["COPILOT_HOME"] = root.to_s
        legacy_payload["timeline"] << {
          "type" => "assistant_message",
          "role" => "assistant",
          "content" => "legacy partial event"
        }
        legacy_path.write(JSON.pretty_generate(legacy_payload))

        get "/api/sessions/legacy-mixed"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(
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
            issues: [],
            message_snapshots: [
              {
                role: "assistant",
                content: "legacy mixed transcript",
                raw_payload: {
                  role: "assistant",
                  content: "legacy mixed transcript"
                }
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
                  type: "assistant_message",
                  role: "assistant",
                  content: "legacy mixed event",
                  timestamp: "2026-04-26T07:50:01Z"
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
                  type: "assistant_message",
                  role: "assistant",
                  content: "legacy partial event"
                },
                degraded: true,
                issues: [
                  {
                    code: "event.partial_mapping",
                    severity: "warning",
                    message: "event payload matched partially",
                    source_path: legacy_path.to_s,
                    scope: "event",
                    event_sequence: 2
                  }
                ]
              }
            ]
          }
        )
        expect(JSON.parse(response.body, symbolize_names: true).fetch(:data).keys).to contain_exactly(
          :id,
          :source_format,
          :created_at,
          :updated_at,
          :work_context,
          :selected_model,
          :degraded,
          :issues,
          :message_snapshots,
          :timeline
        )
      end
    end

    it "returns session_not_found as a 404 without conflating it with a root failure" do
      with_copilot_history_fixture("mixed_root") do |root|
        ENV["COPILOT_HOME"] = root.to_s

        get "/api/sessions/missing-session"

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(
          error: {
            code: "session_not_found",
            message: "session was not found",
            details: {
              session_id: "missing-session"
            }
          }
        )
      end
    end

    it "returns current dotted sessions with canonical helper fields in the shared detail response" do
      with_copilot_history_fixture("current_schema_valid") do |root|
        ENV["COPILOT_HOME"] = root.to_s

        get "/api/sessions/current-schema-valid"

        expect(response).to have_http_status(:ok)

        payload = JSON.parse(response.body, symbolize_names: true).fetch(:data)
        timeline = payload.fetch(:timeline)
        assistant_message = timeline.find { |event| event.fetch(:sequence) == 4 }
        empty_tool_request = timeline.find { |event| event.fetch(:sequence) == 5 }
        detail_event = timeline.find { |event| event.fetch(:raw_type) == "tool.execution_start" }
        expect(payload.fetch(:source_format)).to eq("current")
        expect(payload.fetch(:message_snapshots)).to eq([])
        expect(timeline.map { |event| [ event.fetch(:sequence), event.fetch(:kind), event.fetch(:mapping_status) ] }).to eq(
          [
            [ 1, "message", "complete" ],
            [ 2, "message", "complete" ],
            [ 3, "detail", "complete" ],
            [ 4, "message", "complete" ],
            [ 5, "message", "complete" ],
            [ 6, "detail", "complete" ],
            [ 7, "detail", "complete" ],
            [ 8, "detail", "complete" ],
            [ 9, "detail", "complete" ]
          ]
        )
        expect(assistant_message).to include(
          role: "assistant",
          content: "I can inspect the latest sessions.",
          tool_calls: [
            {
              name: "functions.bash",
              arguments_preview: "{\"command\":\"git --no-pager status\",\"description\":\"Inspect repository status\"}",
              is_truncated: false,
              status: "complete"
            }
          ],
          detail: nil
        )
        expect(empty_tool_request).to include(
          role: "assistant",
          content: nil,
          tool_calls: [
            {
              name: "functions.bash",
              arguments_preview: "{\"command\":\"pwd\"}",
              is_truncated: false,
              status: "complete"
            }
          ],
          detail: nil
        )
        expect(detail_event).to include(
          role: nil,
          content: nil,
          tool_calls: [],
          detail: {
            category: "tool_execution",
            title: "tool.execution_start",
            body: "functions.bash / tool-1"
          }
        )
        expect(payload.fetch(:issues)).to eq([])
      end
    end

    it "keeps degraded current detail responses readable while surfacing partial, unknown, and invalid line issues" do
      with_copilot_history_fixture("current_schema_degraded") do |root|
        events_path = root.join("session-state/current-schema-degraded/events.jsonl")
        ENV["COPILOT_HOME"] = root.to_s

        get "/api/sessions/current-schema-degraded"

        expect(response).to have_http_status(:ok)

        payload = JSON.parse(response.body, symbolize_names: true).fetch(:data)
        timeline = payload.fetch(:timeline)

        expect(payload).to include(
          id: "current-schema-degraded",
          source_format: "current",
          created_at: "2026-04-28T02:00:00Z",
          updated_at: "2026-04-28T02:00:04Z",
          degraded: true,
          message_snapshots: []
        )
        expect(payload.fetch(:issues)).to include(
          {
            code: "current.event_parse_failed",
            severity: "error",
            message: "events.jsonl line could not be parsed",
            source_path: events_path.to_s,
            scope: "event",
            event_sequence: 5
          }
        )
        expect(timeline.map { |event| [ event.fetch(:sequence), event.fetch(:kind), event.fetch(:mapping_status), event.fetch(:degraded) ] }).to eq(
          [
            [ 1, "message", "complete", false ],
            [ 2, "message", "partial", true ],
            [ 3, "detail", "complete", false ],
            [ 4, "unknown", "complete", true ]
          ]
        )
        expect(timeline.fetch(1)).to include(
          role: "assistant",
          content: "Starting diagnostics.",
          tool_calls: [
            {
              name: nil,
              arguments_preview: "{\"command\":\"printenv\",\"token\":\"[REDACTED]\"}",
              is_truncated: false,
              status: "partial"
            }
          ],
          detail: nil
        )
        expect(timeline.fetch(1).fetch(:issues)).to eq(
          [
            {
              code: "event.partial_mapping",
              severity: "warning",
              message: "event payload matched partially",
              source_path: events_path.to_s,
              scope: "event",
              event_sequence: 2
            }
          ]
        )
        expect(timeline.fetch(2)).to include(
          detail: {
            category: "hook",
            title: "hook.start",
            body: "before-tool / *"
          }
        )
        expect(timeline.fetch(3)).to include(
          raw_type: "mystery.event",
          content: nil,
          detail: nil
        )
        expect(timeline.fetch(3).fetch(:issues)).to eq(
          [
            {
              code: "event.unknown_shape",
              severity: "warning",
              message: "event payload could not be mapped to canonical fields",
              source_path: events_path.to_s,
              scope: "event",
              event_sequence: 4
            }
          ]
        )
      end
    end

    it "reuses the shared root failure envelope for detail requests" do
      Dir.mktmpdir("copilot-history-home") do |home|
        ENV.delete("COPILOT_HOME")
        ENV["HOME"] = home

        get "/api/sessions/legacy-mixed"

        expect(response).to have_http_status(:service_unavailable)
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(
          error: {
            code: "root_missing",
            message: "history root does not exist",
            details: {
              path: File.join(home, ".copilot")
            }
          }
        )
      end
    end
  end

  describe "read-only contract" do
    it "does not expose mutating session routes" do
      post "/api/sessions"
      expect(response).to have_http_status(:not_found)

      patch "/api/sessions/legacy-mixed"
      expect(response).to have_http_status(:not_found)

      delete "/api/sessions/legacy-mixed"
      expect(response).to have_http_status(:not_found)
    end
  end
end
