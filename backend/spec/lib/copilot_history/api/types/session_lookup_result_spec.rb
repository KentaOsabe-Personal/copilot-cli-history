require "rails_helper"

RSpec.describe CopilotHistory::Api::Types::SessionLookupResult do
  describe "public states" do
    it "only exposes found and not found states for detail lookup" do
      expect(described_class.constants(false)).to contain_exactly(:Found, :NotFound)
    end
  end

  describe described_class::Found do
    it "carries the stored detail payload without raw reader state" do
      detail_payload = {
        id: "session-123",
        source_format: "current",
        timeline: [],
        raw_included: false
      }

      result = described_class.new(detail_payload:)

      expect(described_class.members).to eq([ :detail_payload ])
      expect(result.detail_payload).to eq(detail_payload)
      expect(result).not_to respond_to(:root)
      expect(result).not_to respond_to(:session)
    end

    it "exposes legacy presenter state only when explicitly provided" do
      session = instance_double("NormalizedSession")
      result = described_class.new(root: nil, session:)

      expect(result).to respond_to(:root)
      expect(result).to respond_to(:session)
      expect(result.root).to be_nil
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
