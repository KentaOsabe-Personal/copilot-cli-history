module CopilotHistory
  module Types
    class ResolvedHistoryRoot < Data.define(:root_path, :current_root, :legacy_root)
      def initialize(root_path:, current_root:, legacy_root:)
        super(
          root_path: pathname(root_path),
          current_root: pathname(current_root),
          legacy_root: pathname(legacy_root)
        )
      end

      private

      def pathname(value)
        value.is_a?(Pathname) ? value : Pathname.new(value.to_s)
      end
    end
  end
end
