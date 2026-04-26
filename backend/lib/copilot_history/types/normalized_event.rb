module CopilotHistory
  module Types
    class NormalizedEvent < Data.define(:sequence, :kind, :raw_type, :occurred_at, :role, :content, :raw_payload)
      def initialize(sequence:, kind:, raw_type:, occurred_at:, role:, content:, raw_payload:)
        super(
          sequence: Integer(sequence),
          kind: kind.to_sym,
          raw_type: raw_type.to_s,
          occurred_at: normalize_time(occurred_at),
          role: role,
          content: content,
          raw_payload: raw_payload
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
