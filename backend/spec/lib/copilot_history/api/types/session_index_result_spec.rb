require "rails_helper"

RSpec.describe CopilotHistory::Api::Types::SessionIndexResult do
  describe "public states" do
    it "exposes success and invalid query states for list lookup" do
      expect(described_class.constants(false)).to contain_exactly(:Success, :Invalid)
    end
  end

  describe described_class::Success do
    it "carries stored summary payloads and response meta without raw reader state" do
      data = [
        {
          id: "session-123",
          source_format: "current",
          degraded: false
        }
      ]
      meta = {
        count: 1,
        partial_results: false
      }

      result = described_class.new(data:, meta:)

      expect(described_class.members).to eq(%i[data meta])
      expect(result.data).to eq(data)
      expect(result.meta).to eq(meta)
      expect(result).not_to respond_to(:root)
      expect(result).not_to respond_to(:sessions)
    end
  end

  describe described_class::Invalid do
    it "carries invalid list query details for the HTTP error boundary" do
      result = described_class.new(
        code: "invalid_session_list_query",
        message: "session list query is invalid",
        details: {
          field: "limit",
          reason: "positive_integer_required"
        }
      )

      expect(described_class.members).to eq(%i[code message details])
      expect(result.code).to eq("invalid_session_list_query")
      expect(result.message).to eq("session list query is invalid")
      expect(result.details).to eq(
        field: "limit",
        reason: "positive_integer_required"
      )
    end
  end
end
