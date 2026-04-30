module CopilotHistory
  module Sync
    module SyncResult
      class Succeeded < Data.define(:sync_run)
        def succeeded?
          true
        end

        def conflict?
          false
        end

        def failed?
          false
        end
      end

      class Conflict < Data.define(:running_run)
        def succeeded?
          false
        end

        def conflict?
          true
        end

        def failed?
          false
        end
      end

      class Failed < Data.define(:sync_run, :code, :message, :details)
        def initialize(sync_run:, code:, message:, details: {})
          super(sync_run:, code: code.to_s, message:, details:)
        end

        def succeeded?
          false
        end

        def conflict?
          false
        end

        def failed?
          true
        end
      end
    end
  end
end
