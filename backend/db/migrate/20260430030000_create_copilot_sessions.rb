class CreateCopilotSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :copilot_sessions do |t|
      t.string :session_id, null: false
      t.string :source_format, null: false
      t.string :source_state, null: false
      t.datetime :created_at_source
      t.datetime :updated_at_source
      t.text :cwd
      t.text :git_root
      t.string :repository
      t.string :branch
      t.string :selected_model
      t.integer :event_count, null: false, default: 0
      t.integer :message_snapshot_count, null: false, default: 0
      t.integer :issue_count, null: false, default: 0
      t.boolean :degraded, null: false, default: false
      t.text :conversation_preview
      t.integer :message_count, null: false, default: 0
      t.integer :activity_count, null: false, default: 0
      t.json :source_paths, null: false
      t.json :source_fingerprint, null: false
      t.json :summary_payload, null: false
      t.json :detail_payload, null: false
      t.datetime :indexed_at, null: false

      t.timestamps
    end

    add_index :copilot_sessions, :session_id, unique: true
    add_index :copilot_sessions, :updated_at_source
    add_index :copilot_sessions, :created_at_source
    add_index :copilot_sessions, :source_format
    add_index :copilot_sessions, :source_state
    add_index :copilot_sessions, :repository
    add_index :copilot_sessions, :branch
  end
end
