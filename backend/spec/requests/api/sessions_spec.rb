require "rails_helper"

RSpec.describe "API Sessions", type: :request do
  before do
    host! "localhost"
  end

  describe "GET /api/sessions" do
    it "returns stored summary payloads and meta through the existing top-level structure" do
      create_copilot_session(
        session_id: "legacy-session",
        source_format: "legacy",
        updated_at_source: "2026-04-26T09:00:00Z",
        summary_payload: {
          "id" => "legacy-session",
          "source_format" => "legacy",
          "degraded" => false,
          "issues" => []
        }
      )
      create_copilot_session(
        session_id: "current-session",
        source_format: "current",
        updated_at_source: "2026-04-26T10:00:00Z",
        summary_payload: {
          "id" => "current-session",
          "source_format" => "current",
          "degraded" => true,
          "issues" => [ { "code" => "partial" } ]
        }
      )

      get "/api/sessions", params: { from: "2026-04-01", to: "2026-04-30", limit: "1" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(
        data: [
          {
            id: "current-session",
            source_format: "current",
            degraded: true,
            issues: [ { code: "partial" } ]
          }
        ],
        meta: {
          count: 1,
          partial_results: true
        }
      )
    end

    it "returns an empty success response when the read model has no sessions" do
      get "/api/sessions", params: { from: "2026-04-01", to: "2026-04-30" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(
        data: [],
        meta: {
          count: 0,
          partial_results: false
        }
      )
    end

    it "returns a 400 error envelope before running the query for invalid list params" do
      expect(CopilotHistory::Api::SessionIndexQuery).not_to receive(:new)

      get "/api/sessions", params: { from: "2026-05-01", to: "2026-04-01" }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(
        error: {
          code: "invalid_session_list_query",
          message: "session list query is invalid",
          details: {
            field: "range",
            reason: "from_after_to"
          }
        }
      )
    end
  end

  describe "GET /api/sessions/:id" do
    it "returns the stored detail payload without rereading raw files when include_raw is requested" do
      detail_payload = {
        "id" => "current-session",
        "source_format" => "current",
        "raw_included" => false,
        "conversation" => {
          "entries" => [
            {
              "sequence" => 1,
              "role" => "user",
              "content" => "saved detail"
            }
          ]
        },
        "timeline" => []
      }
      create_copilot_session(session_id: "current-session", detail_payload: detail_payload)

      expect(CopilotHistory::SessionCatalogReader).not_to receive(:new)

      get "/api/sessions/current-session", params: { include_raw: "true" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(
        data: {
          id: "current-session",
          source_format: "current",
          raw_included: false,
          conversation: {
            entries: [
              {
                sequence: 1,
                role: "user",
                content: "saved detail"
              }
            ]
          },
          timeline: []
        }
      )
    end

    it "returns session_not_found with the requested session id for missing read model rows" do
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

  describe "read-only contract" do
    it "does not expose mutating session routes" do
      post "/api/sessions"
      expect(response).to have_http_status(:not_found)

      patch "/api/sessions/current-session"
      expect(response).to have_http_status(:not_found)

      delete "/api/sessions/current-session"
      expect(response).to have_http_status(:not_found)
    end
  end

  def create_copilot_session(session_id:, source_format: "current", created_at_source: nil, updated_at_source: nil, summary_payload: nil, detail_payload: nil)
    CopilotSession.create!(
      session_id: session_id,
      source_format: source_format,
      source_state: "complete",
      created_at_source: parse_time(created_at_source),
      updated_at_source: parse_time(updated_at_source || created_at_source || "2026-04-26T10:00:00Z"),
      cwd: "/work/#{session_id}",
      git_root: "/work/#{session_id}",
      repository: "example/repo",
      branch: "main",
      selected_model: "gpt-5",
      event_count: 1,
      message_snapshot_count: 1,
      issue_count: 0,
      degraded: false,
      conversation_preview: "summary",
      message_count: 1,
      activity_count: 1,
      source_paths: { "source" => "/tmp/#{session_id}.json" },
      source_fingerprint: { "complete" => true },
      summary_payload: summary_payload || { "id" => session_id, "degraded" => false, "issues" => [] },
      detail_payload: detail_payload || { "id" => session_id, "conversation" => {}, "timeline" => [] },
      indexed_at: Time.zone.parse("2026-04-30T00:00:00Z")
    )
  end

  def parse_time(value)
    value && Time.zone.parse(value)
  end
end
