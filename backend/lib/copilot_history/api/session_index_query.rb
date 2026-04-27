module CopilotHistory
  module Api
    class SessionIndexQuery
      def initialize(session_catalog_reader: CopilotHistory::SessionCatalogReader.new)
        @session_catalog_reader = session_catalog_reader
      end

      def call
        result = session_catalog_reader.call
        return result if result.failure?

        CopilotHistory::Types::ReadResult::Success.new(
          root: result.root,
          sessions: result.sessions.sort_by do |session|
            [
              -sort_time_for(session).to_f,
              session.session_id
            ]
          end
        )
      end

      private

      attr_reader :session_catalog_reader

      def sort_time_for(session)
        session.updated_at || session.created_at || Time.at(0)
      end
    end
  end
end
