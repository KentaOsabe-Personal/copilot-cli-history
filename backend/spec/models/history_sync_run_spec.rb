require "rails_helper"

RSpec.describe HistorySyncRun do
  def valid_attributes
    {
      started_at: Time.zone.parse("2026-04-30 03:00:00"),
      finished_at: Time.zone.parse("2026-04-30 03:01:00"),
      status: "succeeded",
      processed_count: 3,
      saved_count: 2,
      skipped_count: 1,
      failed_count: 0,
      degraded_count: 0
    }
  end

  it "accepts canonical terminal statuses with a finished timestamp" do
    %w[succeeded failed completed_with_issues].each do |status|
      run = described_class.new(valid_attributes.merge(status: status))

      expect(run).to be_valid
    end
  end

  it "accepts a running sync without a finished timestamp" do
    run = described_class.new(valid_attributes.merge(status: "running", finished_at: nil))

    expect(run).to be_valid
  end

  it "requires a finished timestamp for terminal statuses" do
    %w[succeeded failed completed_with_issues].each do |status|
      run = described_class.new(valid_attributes.merge(status: status, finished_at: nil))

      expect(run).not_to be_valid
      expect(run.errors[:finished_at]).to be_present
    end
  end

  it "rejects unknown statuses" do
    run = described_class.new(valid_attributes.merge(status: "partial"))

    expect(run).not_to be_valid
    expect(run.errors[:status]).to be_present
  end

  it "requires count fields to be non-negative integers" do
    count_fields = %i[processed_count saved_count skipped_count failed_count degraded_count]

    count_fields.each do |field|
      run = described_class.new(valid_attributes.merge(field => -1))

      expect(run).not_to be_valid
      expect(run.errors[field]).to be_present
    end
  end

  it "stores root failures independently of session rows" do
    run = described_class.new(
      valid_attributes.merge(
        status: "failed",
        processed_count: 0,
        saved_count: 0,
        failed_count: 1,
        failure_summary: "history root is unreadable"
      )
    )

    expect(run).to be_valid
  end

  it "stores partial degradation separately from complete success" do
    run = described_class.new(
      valid_attributes.merge(
        status: "completed_with_issues",
        degraded_count: 2,
        degradation_summary: "2 sessions degraded"
      )
    )

    expect(run).to be_valid
    expect(run.status).to eq("completed_with_issues")
    expect(run.degraded_count).to eq(2)
  end
end
