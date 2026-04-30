class CreateHistorySyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :history_sync_runs do |t|
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :status, null: false
      t.integer :processed_count, null: false, default: 0
      t.integer :saved_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.integer :degraded_count, null: false, default: 0
      t.text :failure_summary
      t.text :degradation_summary

      t.timestamps
    end

    add_index :history_sync_runs, :started_at
    add_index :history_sync_runs, :status
  end
end
