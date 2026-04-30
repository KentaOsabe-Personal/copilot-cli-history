require "rails_helper"

RSpec.describe HistorySyncRun do
  def valid_attributes
    {
      started_at: Time.zone.parse("2026-04-30 03:00:00"),
      finished_at: Time.zone.parse("2026-04-30 03:01:00"),
      status: "succeeded",
      processed_count: 3,
      inserted_count: 1,
      updated_count: 1,
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
    run = described_class.new(
      valid_attributes.merge(
        status: "running",
        finished_at: nil,
        running_lock_key: "history-sync"
      )
    )

    expect(run).to be_valid
  end

  it "requires a running lock for running status" do
    run = described_class.new(valid_attributes.merge(status: "running", finished_at: nil, running_lock_key: nil))

    expect(run).not_to be_valid
    expect(run.errors[:running_lock_key]).to be_present
  end

  it "rejects a running sync with a finished timestamp" do
    run = described_class.new(valid_attributes.merge(status: "running", running_lock_key: "history-sync"))

    expect(run).not_to be_valid
    expect(run.errors[:finished_at]).to be_present
  end

  it "requires a finished timestamp for terminal statuses" do
    %w[succeeded failed completed_with_issues].each do |status|
      run = described_class.new(valid_attributes.merge(status: status, finished_at: nil))

      expect(run).not_to be_valid
      expect(run.errors[:finished_at]).to be_present
    end
  end

  it "requires terminal statuses to release the running lock" do
    %w[succeeded failed completed_with_issues].each do |status|
      run = described_class.new(valid_attributes.merge(status: status, running_lock_key: "history-sync"))

      expect(run).not_to be_valid
      expect(run.errors[:running_lock_key]).to be_present
    end
  end

  it "rejects unknown statuses" do
    run = described_class.new(valid_attributes.merge(status: "partial"))

    expect(run).not_to be_valid
    expect(run.errors[:status]).to be_present
  end

  it "requires count fields to be non-negative integers" do
    count_fields = %i[
      processed_count
      inserted_count
      updated_count
      saved_count
      skipped_count
      failed_count
      degraded_count
    ]

    count_fields.each do |field|
      run = described_class.new(valid_attributes.merge(field => -1))

      expect(run).not_to be_valid
      expect(run.errors[field]).to be_present
    end
  end

  it "reports invalid count fields without raising from saved count validation" do
    run = described_class.new(valid_attributes.merge(inserted_count: nil, updated_count: "not-a-number"))

    expect { run.valid? }.not_to raise_error
    expect(run.errors[:inserted_count]).to be_present
    expect(run.errors[:updated_count]).to be_present
  end

  it "requires saved count to equal inserted count plus updated count" do
    run = described_class.new(valid_attributes.merge(inserted_count: 1, updated_count: 2, saved_count: 2))

    expect(run).not_to be_valid
    expect(run.errors[:saved_count]).to be_present
  end

  it "stores root failures independently of session rows" do
    run = described_class.new(
      valid_attributes.merge(
        status: "failed",
        processed_count: 0,
        inserted_count: 0,
        updated_count: 0,
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
