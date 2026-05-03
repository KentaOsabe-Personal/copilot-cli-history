module CopilotHistory
  module Api
    class SessionDetailQuery
      def initialize(model: CopilotSession)
        @model = model
      end

      def call(session_id:)
        session = model.find_by(session_id: session_id)
        return Types::SessionLookupResult::NotFound.new(session_id: session_id) if session.nil?

        Types::SessionLookupResult::Found.new(detail_payload: session.detail_payload)
      end

      private

      attr_reader :model
    end
  end
end
