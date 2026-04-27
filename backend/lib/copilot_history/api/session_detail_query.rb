module CopilotHistory
  module Api
    class SessionDetailQuery
      def initialize(session_catalog_reader: CopilotHistory::SessionCatalogReader.new)
        @session_catalog_reader = session_catalog_reader
      end

      def call(session_id:)
        result = session_catalog_reader.call
        return result if result.failure?

        session = result.sessions.find { |candidate| candidate.session_id == session_id }
        return CopilotHistory::Api::Types::SessionLookupResult::NotFound.new(session_id: session_id) if session.nil?

        CopilotHistory::Api::Types::SessionLookupResult::Found.new(
          root: result.root,
          session: session
        )
      end

      private

      attr_reader :session_catalog_reader
    end
  end
end
