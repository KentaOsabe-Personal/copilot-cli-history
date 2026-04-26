require "rails_helper"

RSpec.describe CopilotHistory::EventNormalizer do
  describe "#call" do
    let(:source_path) { Pathname("/tmp/copilot-history/events.jsonl") }
    subject(:normalizer) { described_class.new(source_path: source_path) }

    shared_examples "a known normalized message" do |source_format|
      it "normalizes a known #{source_format} message event without emitting issues" do
        result = normalizer.call(
          raw_event: {
            "type" => "user_message",
            "role" => "user",
            "content" => "show recent sessions",
            "timestamp" => "2026-04-26T09:00:01Z"
          },
          source_format: source_format,
          sequence: 1
        )

        expect(result).to eq(
          CopilotHistory::Types::NormalizationResult.new(
            event: CopilotHistory::Types::NormalizedEvent.new(
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
            issues: []
          )
        )
      end
    end

    shared_examples "a partially normalized message" do |source_format|
      it "returns a partial #{source_format} event with a compatibility warning when a known message shape is incomplete" do
        result = normalizer.call(
          raw_event: {
            "type" => "assistant_message",
            "role" => "assistant",
            "content" => "partial response"
          },
          source_format: source_format,
          sequence: 4
        )

        expect(result.event).to eq(
          CopilotHistory::Types::NormalizedEvent.new(
            sequence: 4,
            kind: :partial,
            raw_type: "assistant_message",
            occurred_at: nil,
            role: "assistant",
            content: "partial response",
            raw_payload: {
              "type" => "assistant_message",
              "role" => "assistant",
              "content" => "partial response"
            }
          )
        )
        expect(result.issues).to eq(
          [
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::EVENT_PARTIAL_MAPPING,
              message: "event payload matched partially",
              source_path: source_path,
              sequence: 4,
              severity: :warning
            )
          ]
        )
      end
    end

    shared_examples "an unknown normalized event" do |source_format|
      it "returns an unknown #{source_format} event and preserves the raw payload for unsupported shapes" do
        result = normalizer.call(
          raw_event: {
            "type" => "mystery-event",
            "payload" => { "value" => 42 },
            "timestamp" => "2026-04-26T09:00:03Z"
          },
          source_format: source_format,
          sequence: 9
        )

        expect(result.event).to eq(
          CopilotHistory::Types::NormalizedEvent.new(
            sequence: 9,
            kind: :unknown,
            raw_type: "mystery-event",
            occurred_at: nil,
            role: nil,
            content: nil,
            raw_payload: {
              "type" => "mystery-event",
              "payload" => { "value" => 42 },
              "timestamp" => "2026-04-26T09:00:03Z"
            }
          )
        )
        expect(result.issues).to eq(
          [
            CopilotHistory::Types::ReadIssue.new(
              code: CopilotHistory::Errors::ReadErrorCode::EVENT_UNKNOWN_SHAPE,
              message: "event payload could not be mapped to canonical fields",
              source_path: source_path,
              sequence: 9,
              severity: :warning
            )
          ]
        )
      end
    end

    include_examples "a known normalized message", :current
    include_examples "a known normalized message", :legacy
    include_examples "a partially normalized message", :current
    include_examples "a partially normalized message", :legacy
    include_examples "an unknown normalized event", :current
    include_examples "an unknown normalized event", :legacy
  end
end
