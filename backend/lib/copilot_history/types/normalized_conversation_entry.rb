module CopilotHistory
  module Types
    class NormalizedConversationEntry < Data.define(
      :sequence,
      :role,
      :content,
      :occurred_at,
      :tool_calls,
      :degraded,
      :issues
    )
      VALID_ROLES = %w[user assistant].freeze

      def initialize(sequence:, role:, content:, occurred_at:, tool_calls:, degraded:, issues:)
        normalized_role = role.to_s
        raise ArgumentError, "role must be one of: #{VALID_ROLES.join(", ")}" unless VALID_ROLES.include?(normalized_role)

        super(
          sequence: Integer(sequence),
          role: normalized_role,
          content: content.to_s,
          occurred_at: normalize_time(occurred_at),
          tool_calls: tool_calls.freeze,
          degraded: !!degraded,
          issues: issues.freeze
        )
      end

      private

      def normalize_time(value)
        return value if value.nil? || value.is_a?(Time)

        Time.iso8601(value.to_s)
      end
    end
  end
end
