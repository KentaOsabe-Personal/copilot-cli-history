module CopilotHistory
  module Api
    module Types
      module SessionLookupResult
        class Found < Data.define(:root, :session)
        end

        class NotFound < Data.define(:session_id)
        end
      end
    end
  end
end
