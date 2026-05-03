module CopilotHistory
  module Api
    module Types
      module SessionIndexResult
        class Success < Data.define(:data, :meta)
        end

        class Invalid < Data.define(:code, :message, :details)
        end
      end
    end
  end
end
