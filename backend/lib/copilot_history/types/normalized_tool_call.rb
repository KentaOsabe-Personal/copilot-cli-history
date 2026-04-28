module CopilotHistory
  module Types
    class NormalizedToolCall < Data.define(:name, :arguments_preview, :is_truncated, :status)
      VALID_STATUSES = %i[complete partial].freeze

      def initialize(name:, arguments_preview:, is_truncated:, status:)
        normalized_status = status.to_sym
        unless VALID_STATUSES.include?(normalized_status)
          raise ArgumentError, "status must be one of: #{VALID_STATUSES.join(", ")}"
        end

        super(
          name: presence(name),
          arguments_preview: presence(arguments_preview),
          is_truncated: !!is_truncated,
          status: normalized_status
        )
      end

      private

      def presence(value)
        return nil if value.nil?

        string_value = value.to_s
        string_value.empty? ? nil : string_value
      end
    end
  end
end
