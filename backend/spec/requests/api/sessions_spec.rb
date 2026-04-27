require "rails_helper"

RSpec.describe "API Sessions", type: :request do
  let(:root) do
    CopilotHistory::Types::ResolvedHistoryRoot.new(
      root_path: "/tmp/copilot",
      current_root: "/tmp/copilot/session-state",
      legacy_root: "/tmp/copilot/history-session-state"
    )
  end

  let(:session) do
    CopilotHistory::Types::NormalizedSession.new(
      session_id: "session-123",
      source_format: :current,
      created_at: "2026-04-26T10:00:00Z",
      updated_at: "2026-04-26T10:05:00Z",
      events: [],
      message_snapshots: [],
      issues: [],
      source_paths: {
        source: "/tmp/copilot/session-state/session-123"
      }
    )
  end

  let(:read_failure) do
    CopilotHistory::Types::ReadFailure.new(
      code: CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE,
      path: "/tmp/copilot",
      message: "history root could not be read"
    )
  end

  before do
    host! "localhost"
  end

  describe "GET /api/sessions" do
    let(:query) { instance_double(CopilotHistory::Api::SessionIndexQuery) }
    let(:presenter) { instance_double(CopilotHistory::Api::Presenters::SessionIndexPresenter) }
    let(:error_presenter) { instance_double(CopilotHistory::Api::Presenters::ErrorPresenter) }

    before do
      allow(CopilotHistory::Api::SessionIndexQuery).to receive(:new).and_return(query)
      allow(CopilotHistory::Api::Presenters::SessionIndexPresenter).to receive(:new).and_return(presenter)
      allow(CopilotHistory::Api::Presenters::ErrorPresenter).to receive(:new).and_return(error_presenter)
    end

    it "renders the list presenter payload for successful query results" do
      result = CopilotHistory::Types::ReadResult::Success.new(root:, sessions: [ session ])
      payload = {
        data: [
          {
            id: "session-123",
            source_format: "current",
            degraded: false
          }
        ],
        meta: {
          count: 1,
          partial_results: false
        }
      }

      allow(query).to receive(:call).and_return(result)
      expect(presenter).to receive(:call).with(result:).and_return(payload)

      get "/api/sessions"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(payload)
    end

    it "renders the shared error envelope for root failures" do
      result = CopilotHistory::Types::ReadResult::Failure.new(failure: read_failure)
      payload = {
        error: {
          code: read_failure.code,
          message: read_failure.message,
          details: {
            path: read_failure.path.to_s
          }
        }
      }

      allow(query).to receive(:call).and_return(result)
      expect(error_presenter).to receive(:from_read_failure).with(failure: read_failure).and_return([ :service_unavailable, payload ])

      get "/api/sessions"

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(payload)
    end
  end

  describe "GET /api/sessions/:id" do
    let(:query) { instance_double(CopilotHistory::Api::SessionDetailQuery) }
    let(:presenter) { instance_double(CopilotHistory::Api::Presenters::SessionDetailPresenter) }
    let(:error_presenter) { instance_double(CopilotHistory::Api::Presenters::ErrorPresenter) }

    before do
      allow(CopilotHistory::Api::SessionDetailQuery).to receive(:new).and_return(query)
      allow(CopilotHistory::Api::Presenters::SessionDetailPresenter).to receive(:new).and_return(presenter)
      allow(CopilotHistory::Api::Presenters::ErrorPresenter).to receive(:new).and_return(error_presenter)
    end

    it "renders the detail presenter payload for found results" do
      result = CopilotHistory::Api::Types::SessionLookupResult::Found.new(root:, session:)
      payload = {
        data: {
          id: "session-123",
          timeline: []
        }
      }

      allow(query).to receive(:call).with(session_id: "session-123").and_return(result)
      expect(presenter).to receive(:call).with(result:).and_return(payload)

      get "/api/sessions/session-123"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(payload)
    end

    it "renders a session_not_found envelope for lookup misses" do
      result = CopilotHistory::Api::Types::SessionLookupResult::NotFound.new(session_id: "missing-session")
      payload = {
        error: {
          code: "session_not_found",
          message: "session was not found",
          details: {
            session_id: "missing-session"
          }
        }
      }

      allow(query).to receive(:call).with(session_id: "missing-session").and_return(result)
      expect(error_presenter).to receive(:from_not_found).with(session_id: "missing-session").and_return([ :not_found, payload ])

      get "/api/sessions/missing-session"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(payload)
    end

    it "reuses the shared root failure envelope for detail requests" do
      result = CopilotHistory::Types::ReadResult::Failure.new(failure: read_failure)
      payload = {
        error: {
          code: read_failure.code,
          message: read_failure.message,
          details: {
            path: read_failure.path.to_s
          }
        }
      }

      allow(query).to receive(:call).with(session_id: "session-123").and_return(result)
      expect(error_presenter).to receive(:from_read_failure).with(failure: read_failure).and_return([ :service_unavailable, payload ])

      get "/api/sessions/session-123"

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(payload)
    end
  end
end
