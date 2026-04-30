class HistorySyncRun < ApplicationRecord
  STATUSES = %w[running succeeded failed completed_with_issues].freeze
  TERMINAL_STATUSES = STATUSES - [ "running" ]
  COUNT_FIELDS = %i[
    processed_count
    saved_count
    skipped_count
    failed_count
    degraded_count
  ].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  validates(*COUNT_FIELDS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })

  validate :finished_at_is_present_for_terminal_status

  private

  def finished_at_is_present_for_terminal_status
    return unless TERMINAL_STATUSES.include?(status)
    return if finished_at.present?

    errors.add(:finished_at, :blank)
  end
end
