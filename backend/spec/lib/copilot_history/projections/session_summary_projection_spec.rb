require "rails_helper"

RSpec.describe "CopilotHistory session projection summary", :copilot_history do
  it "derives conversation presence, preview, message count, and activity count from normalized sessions" do
    with_copilot_history_fixture("current_schema_mixed_root") do |root|
      resolved_root = CopilotHistory::Types::ResolvedHistoryRoot.new(
        root_path: root,
        current_root: root.join("session-state"),
        legacy_root: root.join("history-session-state")
      )
      sessions = CopilotHistory::SessionSourceCatalog.new.call(resolved_root).map do |source|
        case source.format
        when :current
          CopilotHistory::CurrentSessionReader.new.call(source)
        when :legacy
          CopilotHistory::LegacySessionReader.new.call(source)
        end
      end
      conversation_projector = CopilotHistory::Projections::ConversationProjector.new
      activity_projector = CopilotHistory::Projections::ActivityProjector.new

      summaries = sessions.to_h do |session|
        conversation = conversation_projector.call(session)
        activity = activity_projector.call(session)

        [
          session.session_id,
          conversation.summary.with(activity_count: activity.entries.length)
        ]
      end

      expect(summaries.fetch("current-schema-mixed")).to have_attributes(
        has_conversation: true,
        message_count: 2,
        preview: "current mixed question",
        activity_count: 0
      )
      expect(summaries.fetch("legacy-schema-mixed")).to have_attributes(
        has_conversation: true,
        message_count: 2,
        preview: "legacy mixed question",
        activity_count: 0
      )
    end
  end
end
