class HistorySyncRun < ApplicationRecord
  STATUSES = %w[running succeeded failed completed_with_issues].freeze
  TERMINAL_STATUSES = STATUSES - [ "running" ]
  COUNT_FIELDS = %i[
    processed_count
    inserted_count
    updated_count
    saved_count
    skipped_count
    failed_count
    degraded_count
  ].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  validates(*COUNT_FIELDS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })

  validate :finished_at_is_present_for_terminal_status
  validate :finished_at_is_absent_for_running_status
  validate :running_lock_key_matches_lifecycle
  validate :saved_count_matches_inserted_and_updated_counts

  private

  def finished_at_is_present_for_terminal_status
    return unless TERMINAL_STATUSES.include?(status)
    return if finished_at.present?

    errors.add(:finished_at, :blank)
  end

  def finished_at_is_absent_for_running_status
    return unless status == "running"
    return if finished_at.blank?

    errors.add(:finished_at, :present)
  end

  def running_lock_key_matches_lifecycle
    if status == "running"
      errors.add(:running_lock_key, :blank) if running_lock_key.blank?
    elsif TERMINAL_STATUSES.include?(status)
      errors.add(:running_lock_key, :present) if running_lock_key.present?
    end
  end

  def saved_count_matches_inserted_and_updated_counts
    return unless count_comparable?(saved_count)
    return unless count_comparable?(inserted_count)
    return unless count_comparable?(updated_count)
    return if saved_count == inserted_count + updated_count

    errors.add(:saved_count, :invalid)
  end

  def count_comparable?(value)
    value.is_a?(Integer) && value >= 0
  end
end
