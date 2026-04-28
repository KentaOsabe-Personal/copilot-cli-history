require "rails_helper"

RSpec.describe CopilotHistory::SessionCatalogReader, :copilot_history do
  around do |example|
    original_copilot_home = ENV["COPILOT_HOME"]
    original_home = ENV["HOME"]

    example.run
  ensure
    ENV["COPILOT_HOME"] = original_copilot_home
    ENV["HOME"] = original_home
  end

  describe "#call" do
    it "returns a public success envelope with both current and legacy sessions" do
      with_copilot_history_fixture("mixed_root") do |root|
        ENV["COPILOT_HOME"] = root.to_s

        result = build_reader.call

        expect(result).to be_a(CopilotHistory::Types::ReadResult::Success)
        expect(result.root).to eq(
          CopilotHistory::Types::ResolvedHistoryRoot.new(
            root_path: root,
            current_root: root.join("session-state"),
            legacy_root: root.join("history-session-state")
          )
        )
        expect(result.sessions.map(&:session_id)).to eq(%w[current-mixed legacy-mixed])
        expect(result.sessions.map(&:source_format)).to eq(%i[current legacy])
      end
    end

    it "preserves mixed-session ordering and raw payloads across current unknown and legacy partial events" do
      with_copilot_history_fixture("mixed_root") do |root|
        legacy_path = root.join("history-session-state/legacy-mixed.json")
        legacy_payload = JSON.parse(legacy_path.read)
        legacy_payload["timeline"] << {
          "type" => "assistant_message",
          "role" => "assistant",
          "content" => "legacy partial event"
        }
        legacy_path.write(JSON.pretty_generate(legacy_payload))
        ENV["COPILOT_HOME"] = root.to_s

        result = build_reader.call

        expect(result).to be_a(CopilotHistory::Types::ReadResult::Success)

        current_session = result.sessions.find { |session| session.session_id == "current-mixed" }
        legacy_session = result.sessions.find { |session| session.session_id == "legacy-mixed" }

        expect(current_session).to be_a(CopilotHistory::Types::NormalizedSession)
        expect(legacy_session).to be_a(CopilotHistory::Types::NormalizedSession)
        expect(result.root.root_path).to eq(root)
        expect(current_session.events.map(&:sequence)).to eq([ 1, 2 ])
        expect(current_session.events.last.kind).to eq(:unknown)
        expect(current_session.events.last.raw_payload).to eq(
          {
            "type" => "mystery-event",
            "payload" => { "value" => 42 },
            "timestamp" => "2026-04-26T10:00:02Z"
          }
        )
        expect(legacy_session.events.map(&:sequence)).to eq([ 1, 2 ])
        expect(legacy_session.events.last.kind).to eq(:message)
        expect(legacy_session.events.last.mapping_status).to eq(:partial)
        expect(legacy_session.events.last.raw_payload).to eq(
          {
            "type" => "assistant_message",
            "role" => "assistant",
            "content" => "legacy partial event"
          }
        )
        expect(legacy_session.issues).to include(
          CopilotHistory::Types::ReadIssue.new(
            code: CopilotHistory::Errors::ReadErrorCode::EVENT_PARTIAL_MAPPING,
            message: "event payload matched partially",
            source_path: legacy_path,
            sequence: 2,
            severity: :warning
          )
        )
      end
    end

    it "keeps file-level session issues inside success results instead of promoting them to root failure" do
      with_copilot_history_fixture("mixed_root") do |root|
        workspace_path = root.join("session-state/current-mixed/workspace.yaml")
        ENV["COPILOT_HOME"] = root.to_s

        with_permission_denied(workspace_path) do
          result = build_reader.call

          expect(result).to be_a(CopilotHistory::Types::ReadResult::Success)
          expect(result.sessions.map(&:session_id)).to eq(%w[current-mixed legacy-mixed])
          expect(result.sessions.find { |session| session.session_id == "current-mixed" }.issues).to include(
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_UNREADABLE,
              message: "workspace.yaml is not accessible",
              source_path: workspace_path,
              severity: :error
            )
          )
        end
      end
    end

    it "keeps parse and access failures scoped to sibling sessions without changing the public success envelope" do
      with_copilot_history_fixture("mixed_root") do |root|
        events_path = root.join("session-state/current-mixed/events.jsonl")
        legacy_path = root.join("history-session-state/legacy-mixed.json")
        ENV["COPILOT_HOME"] = root.to_s
        events_path.write(<<~JSONL)
          {"type":"user_message","role":"user","content":"current survives","timestamp":"2026-04-26T10:00:01Z"}
          not-json
        JSONL

        with_permission_denied(legacy_path) do
          result = build_reader.call

          expect(result).to be_a(CopilotHistory::Types::ReadResult::Success)
          expect(result).not_to be_a(CopilotHistory::Types::ReadFailure)
          expect(result.sessions.map(&:session_id)).to eq(%w[current-mixed legacy-mixed])

          current_session = result.sessions.find { |session| session.session_id == "current-mixed" }
          legacy_session = result.sessions.find { |session| session.session_id == "legacy-mixed" }

          expect(current_session.events.map(&:sequence)).to eq([ 1 ])
          expect(current_session.issues).to include(
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENT_PARSE_FAILED,
              message: "events.jsonl line could not be parsed",
              source_path: events_path,
              sequence: 2,
              severity: :error
            )
          )
          expect(legacy_session.events).to eq([])
          expect(legacy_session.issues).to include(
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::LEGACY_SOURCE_UNREADABLE,
              message: "legacy session source is not accessible",
              source_path: legacy_path,
              severity: :error
            )
          )
        end
      end
    end

    it "wraps fatal root failures in the public failure envelope and logs them as error" do
      logger = instance_double(Logger, warn: nil, error: nil)

      Dir.mktmpdir("copilot-history-home") do |home|
        expected_path = Pathname.new(home).join(".copilot")
        ENV.delete("COPILOT_HOME")
        ENV["HOME"] = home

        expect(logger).to receive(:error).with(
          hash_including(
            source_path: expected_path.to_s,
            failure_code: CopilotHistory::Errors::ReadErrorCode::ROOT_MISSING
          )
        )

        result = build_reader(logger: logger).call

        expect(result).to eq(
          CopilotHistory::Types::ReadResult::Failure.new(
            failure: CopilotHistory::Types::ReadFailure.new(
              code: CopilotHistory::Errors::ReadErrorCode::ROOT_MISSING,
              path: expected_path,
              message: "history root does not exist"
            )
          )
        )
      end
    end

    it "returns a public failure envelope when the resolved root exists but is not accessible" do
      Dir.mktmpdir("copilot-history-home") do |home|
        expected_path = Pathname.new(home).join(".copilot")
        expected_path.mkdir
        ENV.delete("COPILOT_HOME")
        ENV["HOME"] = home

        with_permission_denied(expected_path) do
          result = build_reader.call

          expect(result).to be_a(CopilotHistory::Types::ReadResult::Failure)
          expect(result).not_to be_a(CopilotHistory::Types::ReadFailure)
          expect(result).to eq(
            CopilotHistory::Types::ReadResult::Failure.new(
              failure: CopilotHistory::Types::ReadFailure.new(
                code: CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED,
                path: expected_path,
                message: "history root is not accessible"
              )
            )
          )
        end
      end
    end

    it "wraps source catalog access failures in the public failure envelope" do
      logger = instance_double(Logger, warn: nil, error: nil)

      with_copilot_history_fixture("current_valid") do |root|
        current_root = root.join("session-state")
        ENV["COPILOT_HOME"] = root.to_s

        expect(logger).to receive(:error).with(
          hash_including(
            source_path: current_root.to_s,
            failure_code: CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED
          )
        )

        with_permission_denied(current_root) do
          result = build_reader(logger: logger).call

          expect(result).to eq(
            CopilotHistory::Types::ReadResult::Failure.new(
              failure: CopilotHistory::Types::ReadFailure.new(
                code: CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED,
                path: current_root,
                message: "history source directory is not accessible"
              )
            )
          )
        end
      end
    end

    it "keeps session issues in the result without logging them" do
      logger = instance_double(Logger, warn: nil, error: nil)

      with_copilot_history_fixture("mixed_root") do |root|
        workspace_path = root.join("session-state/current-mixed/workspace.yaml")
        ENV["COPILOT_HOME"] = root.to_s

        expect(logger).not_to receive(:warn)

        with_permission_denied(workspace_path) do
          result = build_reader(logger: logger).call

          expect(result).to be_a(CopilotHistory::Types::ReadResult::Success)
          expect(result.sessions.map(&:session_id)).to eq(%w[current-mixed legacy-mixed])
          expect(result.sessions.find { |session| session.session_id == "current-mixed" }.issues).to include(
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_UNREADABLE,
              message: "workspace.yaml is not accessible",
              source_path: workspace_path,
              severity: :error
            )
          )
        end
      end
    end

    it "does not log warning-only session issues while preserving them in the result" do
      logger = instance_double(Logger, warn: nil, error: nil)

      with_copilot_history_fixture("mixed_root") do |root|
        ENV["COPILOT_HOME"] = root.to_s

        expect(logger).not_to receive(:warn)

        result = build_reader(logger: logger).call

        expect(result).to be_a(CopilotHistory::Types::ReadResult::Success)
        expect(result.sessions.flat_map(&:issues).map(&:code)).to include(
          CopilotHistory::Errors::ReadErrorCode::EVENT_UNKNOWN_SHAPE
        )
      end
    end

    def build_reader(logger: instance_double(Logger, warn: nil, error: nil))
      described_class.new(
        root_resolver: CopilotHistory::HistoryRootResolver.new(env: ENV),
        logger: logger
      )
    end
  end
end
