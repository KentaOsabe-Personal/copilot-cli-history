module CopilotHistory
  module Types
    class NormalizedEvent < Data.define(
      :sequence,
      :kind,
      :mapping_status,
      :raw_type,
      :occurred_at,
      :role,
      :content,
      :tool_calls,
      :detail,
      :raw_payload
    )
      VALID_KINDS = %i[message detail unknown].freeze
      VALID_MAPPING_STATUSES = %i[complete partial].freeze

      def initialize(sequence:, kind:, raw_type:, occurred_at:, role:, content:, raw_payload:, mapping_status: :complete, tool_calls: [], detail: nil)
        normalized_kind = kind.to_sym
        unless VALID_KINDS.include?(normalized_kind)
          raise ArgumentError, "kind must be one of: #{VALID_KINDS.join(", ")}"
        end

        normalized_mapping_status = mapping_status.to_sym
        unless VALID_MAPPING_STATUSES.include?(normalized_mapping_status)
          raise ArgumentError, "mapping_status must be one of: #{VALID_MAPPING_STATUSES.join(", ")}"
        end

        super(
          sequence: Integer(sequence),
          kind: normalized_kind,
          mapping_status: normalized_mapping_status,
          raw_type: raw_type.to_s,
          occurred_at: normalize_time(occurred_at),
          role: role,
          content: content,
          tool_calls: normalize_tool_calls(tool_calls),
          detail: normalize_detail(detail),
          raw_payload: raw_payload
        )
      end

      private

      def normalize_time(value)
        return value if value.nil? || value.is_a?(Time)

        Time.iso8601(value.to_s)
      end

      def normalize_tool_calls(values)
        Array(values).map do |tool_call|
          next tool_call if tool_call.is_a?(NormalizedToolCall)

          unless tool_call.is_a?(Hash)
            raise ArgumentError, "tool_calls entries must be hashes or NormalizedToolCall instances"
          end

          NormalizedToolCall.new(**symbolize_keys(tool_call))
        end.freeze
      end

      def normalize_detail(value)
        return nil if value.nil?
        raise ArgumentError, "detail must be a hash" unless value.is_a?(Hash)

        symbolize_keys(value).freeze
      end

      def symbolize_keys(hash)
        hash.each_with_object({}) do |(key, value), normalized|
          normalized[key.to_sym] = value
        end
      end
    end
  end
end
