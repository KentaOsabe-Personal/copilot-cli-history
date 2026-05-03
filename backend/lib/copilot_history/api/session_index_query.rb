module CopilotHistory
  module Api
    class SessionIndexQuery
      DISPLAY_TIME_SQL = "COALESCE(copilot_sessions.updated_at_source, copilot_sessions.created_at_source)".freeze

      def initialize(model: CopilotSession)
        @model = model
      end

      def call(from_time: nil, to_time: nil, limit: nil)
        sessions = model
          .where.not(updated_at_source: nil)
          .or(model.where.not(created_at_source: nil))

        sessions = sessions.where("#{DISPLAY_TIME_SQL} >= ?", from_time) if from_time
        sessions = sessions.where("#{DISPLAY_TIME_SQL} <= ?", to_time) if to_time
        sessions = sessions.order(Arel.sql("#{DISPLAY_TIME_SQL} DESC"), :session_id)
        sessions = sessions.limit(limit) if limit

        data = sessions.map(&:summary_payload)

        Types::SessionIndexResult::Success.new(
          data: data,
          meta: {
            count: data.count,
            partial_results: data.any? { |payload| payload["degraded"] == true }
          }
        )
      end

      private

      attr_reader :model
    end
  end
end
