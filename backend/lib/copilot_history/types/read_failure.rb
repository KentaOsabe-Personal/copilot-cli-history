module CopilotHistory
  module Types
    class ReadFailure < Data.define(:code, :path, :message)
      def initialize(code:, path:, message:)
        normalized_code = code.to_s
        unless CopilotHistory::Errors::ReadErrorCode::ROOT_FAILURE_CODES.include?(normalized_code)
          raise ArgumentError, "code must be a root failure code"
        end

        super(
          code: normalized_code,
          path: pathname(path),
          message: message
        )
      end

      private

      def pathname(value)
        value.is_a?(Pathname) ? value : Pathname.new(value.to_s)
      end
    end
  end
end
