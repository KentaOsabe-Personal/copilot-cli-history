require "rails_helper"

RSpec.describe CopilotHistory::CurrentSessionReader, :copilot_history do
  describe "#call" do
    it "builds one normalized session from workspace.yaml and events.jsonl" do
      with_copilot_history_fixture("current_valid") do |root|
        session = described_class.new.call(build_source(root, "current-valid"))

        expect(session).to eq(
          CopilotHistory::Types::NormalizedSession.new(
            session_id: "current-valid",
            source_format: :current,
            cwd: "/workspace/current-valid",
            git_root: "/workspace/current-valid",
            repository: "octo/example",
            branch: "main",
            created_at: "2026-04-26T09:00:00Z",
            updated_at: "2026-04-26T09:05:00Z",
            selected_model: nil,
            events: [
              CopilotHistory::Types::NormalizedEvent.new(
                sequence: 1,
                kind: :message,
                raw_type: "user_message",
                occurred_at: "2026-04-26T09:00:01Z",
                role: "user",
                content: "show recent sessions",
                raw_payload: {
                  "type" => "user_message",
                  "role" => "user",
                  "content" => "show recent sessions",
                  "timestamp" => "2026-04-26T09:00:01Z"
                }
              ),
              CopilotHistory::Types::NormalizedEvent.new(
                sequence: 2,
                kind: :message,
                raw_type: "assistant_message",
                occurred_at: "2026-04-26T09:00:02Z",
                role: "assistant",
                content: "Here are the latest sessions.",
                raw_payload: {
                  "type" => "assistant_message",
                  "role" => "assistant",
                  "content" => "Here are the latest sessions.",
                  "timestamp" => "2026-04-26T09:00:02Z"
                }
              )
            ],
            message_snapshots: [],
            issues: [],
            source_paths: {
              workspace: root.join("session-state/current-valid/workspace.yaml"),
              events: root.join("session-state/current-valid/events.jsonl")
            }
          )
        )
      end
    end

    it "keeps readable events when workspace.yaml cannot be parsed" do
      with_copilot_history_fixture("current_invalid_yaml") do |root|
        session = described_class.new.call(build_source(root, "current-invalid-yaml"))

        expect(session.session_id).to eq("current-invalid-yaml")
        expect(session.cwd).to be_nil
        expect(session.events).to eq(
          [
            CopilotHistory::Types::NormalizedEvent.new(
              sequence: 1,
              kind: :message,
              raw_type: "user_message",
              occurred_at: "2026-04-26T09:10:01Z",
              role: "user",
              content: "keep events readable",
              raw_payload: {
                "type" => "user_message",
                "role" => "user",
                "content" => "keep events readable",
                "timestamp" => "2026-04-26T09:10:01Z"
              }
            )
          ]
        )
        expect(session.issues).to eq(
          [
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_PARSE_FAILED,
              message: "workspace.yaml could not be parsed",
              source_path: root.join("session-state/current-invalid-yaml/workspace.yaml"),
              severity: :error
            )
          ]
        )
      end
    end

    it "keeps readable lines and reports invalid JSONL lines and unknown events" do
      with_copilot_history_fixture("current_invalid_jsonl") do |root|
        session = described_class.new.call(build_source(root, "current-invalid-jsonl"))

        expect(session.events.map(&:sequence)).to eq([ 1, 3 ])
        expect(session.events.map(&:kind)).to eq(%i[message unknown])
        expect(session.issues).to eq(
          [
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENT_PARSE_FAILED,
              message: "events.jsonl line could not be parsed",
              source_path: root.join("session-state/current-invalid-jsonl/events.jsonl"),
              sequence: 2,
              severity: :error
            ),
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::EVENT_UNKNOWN_SHAPE,
              message: "event payload could not be mapped to canonical fields",
              source_path: root.join("session-state/current-invalid-jsonl/events.jsonl"),
              sequence: 3,
              severity: :warning
            )
          ]
        )
      end
    end

    it "keeps reading when a JSONL line parses into a non-hash payload" do
      with_copilot_history_fixture("current_valid") do |root|
        events_path = root.join("session-state/current-valid/events.jsonl")
        events_path.write(<<~JSONL)
          {"type":"user_message","role":"user","content":"show recent sessions","timestamp":"2026-04-26T09:00:01Z"}
          {"type":"assistant_message","role":"assistant","content":"Here are the latest sessions.","timestamp":"2026-04-26T09:00:02Z"}
          [1,2,3]
        JSONL

        session = described_class.new.call(build_source(root, "current-valid"))

        expect(session.events.map(&:sequence)).to eq([ 1, 2, 3 ])
        expect(session.events.last).to eq(
          CopilotHistory::Types::NormalizedEvent.new(
            sequence: 3,
            kind: :unknown,
            raw_type: "array",
            occurred_at: nil,
            role: nil,
            content: nil,
            raw_payload: [ 1, 2, 3 ]
          )
        )
        expect(session.issues).to include(
          CopilotHistory::Types::ReadIssue.new(
            code: CopilotHistory::Errors::ReadErrorCode::EVENT_UNKNOWN_SHAPE,
            message: "event payload could not be mapped to canonical fields",
            source_path: events_path,
            sequence: 3,
            severity: :warning
          )
        )
      end
    end

    it "returns a session issue when workspace.yaml is unreadable but still keeps readable events" do
      with_copilot_history_fixture("current_unreadable") do |root|
        workspace_path = root.join("session-state/current-unreadable/workspace.yaml")

        with_permission_denied(workspace_path) do
          session = described_class.new.call(build_source(root, "current-unreadable"))

          expect(session.session_id).to eq("current-unreadable")
          expect(session.cwd).to be_nil
          expect(session.events.size).to eq(1)
          expect(session.issues).to eq(
            [
              CopilotHistory::Types::ReadIssue.new(
                code: CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_UNREADABLE,
                message: "workspace.yaml is not accessible",
                source_path: workspace_path,
                severity: :error
              )
            ]
          )
        end
      end
    end

    it "returns a session issue when events.jsonl is unreadable while keeping workspace metadata" do
      with_copilot_history_fixture("current_unreadable") do |root|
        events_path = root.join("session-state/current-unreadable/events.jsonl")

        with_permission_denied(events_path) do
          session = described_class.new.call(build_source(root, "current-unreadable"))

          expect(session.session_id).to eq("current-unreadable")
          expect(session.cwd).to eq(Pathname("/workspace/current-unreadable"))
          expect(session.events).to eq([])
          expect(session.issues).to eq(
            [
              CopilotHistory::Types::ReadIssue.new(
                code: CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENTS_UNREADABLE,
                message: "events.jsonl is not accessible",
                source_path: events_path,
                severity: :error
              )
            ]
          )
        end
      end
    end

    def build_source(root, session_id)
      source_path = root.join("session-state", session_id)

      CopilotHistory::Types::SessionSource.new(
        format: :current,
        session_id: session_id,
        source_path: source_path,
        artifact_paths: {
          workspace: source_path.join("workspace.yaml"),
          events: source_path.join("events.jsonl")
        }
      )
    end
  end
end
