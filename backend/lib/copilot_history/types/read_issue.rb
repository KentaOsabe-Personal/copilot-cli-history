module CopilotHistory
  module Types
    class ReadIssue < Data.define(:code, :message, :source_path, :sequence, :severity)
      VALID_SEVERITIES = %i[warning error].freeze

      def initialize(code:, message:, source_path:, sequence: nil, severity:)
        normalized_code = code.to_s
        if CopilotHistory::Errors::ReadErrorCode::ROOT_FAILURE_CODES.include?(normalized_code)
          raise ArgumentError, "code must not be a root failure code"
        end

        normalized_severity = severity.to_sym
        unless VALID_SEVERITIES.include?(normalized_severity)
          raise ArgumentError, "severity must be one of: #{VALID_SEVERITIES.join(", ")}"
        end

        super(
          code: normalized_code,
          message: message,
          source_path: pathname(source_path),
          sequence: sequence.nil? ? nil : Integer(sequence),
          severity: normalized_severity
        )
      end

      private

      def pathname(value)
        value.is_a?(Pathname) ? value : Pathname.new(value.to_s)
      end
    end
  end
end
