require "rails_helper"

RSpec.describe CopilotHistory::Sync::SyncResult do
  let(:sync_run) do
    HistorySyncRun.new(
      id: 101,
      status: "succeeded",
      started_at: Time.zone.parse("2026-04-30 06:00:00"),
      finished_at: Time.zone.parse("2026-04-30 06:00:02")
    )
  end

  describe CopilotHistory::Sync::SyncResult::Succeeded do
    it "carries a terminal sync run and exposes its result kind" do
      result = described_class.new(sync_run:)

      expect(result.sync_run).to eq(sync_run)
      expect(result).to be_succeeded
      expect(result).not_to be_conflict
      expect(result).not_to be_failed
    end
  end

  describe CopilotHistory::Sync::SyncResult::Conflict do
    it "carries the existing running sync run without replacing it" do
      running_run = HistorySyncRun.new(
        id: 102,
        status: "running",
        started_at: Time.zone.parse("2026-04-30 06:01:00"),
        running_lock_key: "history_sync"
      )
      result = described_class.new(running_run:)

      expect(result.running_run).to eq(running_run)
      expect(result).to be_conflict
      expect(result).not_to be_succeeded
      expect(result).not_to be_failed
    end
  end

  describe CopilotHistory::Sync::SyncResult::Failed do
    it "carries terminal run, failure code, message, and details for root failures" do
      failed_run = HistorySyncRun.new(
        id: 103,
        status: "failed",
        started_at: Time.zone.parse("2026-04-30 06:02:00"),
        finished_at: Time.zone.parse("2026-04-30 06:02:01")
      )
      result = described_class.new(
        sync_run: failed_run,
        code: "root_missing",
        message: "history root does not exist",
        details: { path: "/tmp/missing-root" }
      )

      expect(result.sync_run).to eq(failed_run)
      expect(result.code).to eq("root_missing")
      expect(result.message).to eq("history root does not exist")
      expect(result.details).to eq(path: "/tmp/missing-root")
      expect(result).to be_failed
      expect(result).not_to be_succeeded
      expect(result).not_to be_conflict
    end
  end
end
