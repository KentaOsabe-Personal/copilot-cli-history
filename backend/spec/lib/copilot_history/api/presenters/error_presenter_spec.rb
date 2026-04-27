require "rails_helper"

RSpec.describe CopilotHistory::Api::Presenters::ErrorPresenter do
  describe "#from_read_failure" do
    it "maps each root failure to a 503 envelope while preserving the upstream code" do
      [
        CopilotHistory::Errors::ReadErrorCode::ROOT_MISSING,
        CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED,
        CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE
      ].each do |code|
        failure = CopilotHistory::Types::ReadFailure.new(
          code:,
          path: "/tmp/copilot",
          message: "history root is unavailable"
        )

        status, payload = described_class.new.from_read_failure(failure:)

        expect(status).to eq(:service_unavailable)
        expect(payload).to eq(
          error: {
            code:,
            message: "history root is unavailable",
            details: {
              path: "/tmp/copilot"
            }
          }
        )
      end
    end
  end

  describe "#from_not_found" do
    it "maps lookup misses to a 404 session_not_found envelope" do
      status, payload = described_class.new.from_not_found(session_id: "session-123")

      expect(status).to eq(:not_found)
      expect(payload).to eq(
        error: {
          code: "session_not_found",
          message: "session was not found",
          details: {
            session_id: "session-123"
          }
        }
      )
    end
  end
end
