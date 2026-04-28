module CopilotHistory
  module Types
    class ActivityProjection < Data.define(:entries)
      def initialize(entries:)
        super(entries: entries.freeze)
      end
    end
  end
end
