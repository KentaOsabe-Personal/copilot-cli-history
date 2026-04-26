module CopilotHistory
  module Types
    module ReadResult
      class Success < Data.define(:root, :sessions)
        def initialize(root:, sessions:)
          super(root:, sessions: sessions.freeze)
        end

        def success?
          true
        end

        def failure?
          false
        end
      end

      class Failure < Data.define(:failure)
        def success?
          false
        end

        def failure?
          true
        end
      end
    end
  end
end
