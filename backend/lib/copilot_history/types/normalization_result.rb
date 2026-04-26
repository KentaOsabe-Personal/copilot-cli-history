module CopilotHistory
  module Types
    class NormalizationResult < Data.define(:event, :issues)
      def initialize(event:, issues:)
        super(event:, issues: issues.freeze)
      end
    end
  end
end
