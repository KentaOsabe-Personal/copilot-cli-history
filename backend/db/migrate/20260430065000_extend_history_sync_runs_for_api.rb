class ExtendHistorySyncRunsForApi < ActiveRecord::Migration[8.1]
  def change
    add_column :history_sync_runs, :inserted_count, :integer, null: false, default: 0
    add_column :history_sync_runs, :updated_count, :integer, null: false, default: 0
    add_column :history_sync_runs, :running_lock_key, :string

    add_index :history_sync_runs, :running_lock_key, unique: true
  end
end
