module CopilotHistory
  module Types
    class SessionSource < Data.define(:format, :session_id, :source_path, :artifact_paths)
      VALID_FORMATS = %i[current legacy].freeze

      def initialize(format:, session_id:, source_path:, artifact_paths:)
        normalized_format = format.to_sym
        raise ArgumentError, "format must be one of: #{VALID_FORMATS.join(", ")}" unless VALID_FORMATS.include?(normalized_format)

        super(
          format: normalized_format,
          session_id: session_id,
          source_path: pathname(source_path),
          artifact_paths: normalize_artifact_paths(artifact_paths)
        )
      end

      private

      def pathname(value)
        value.is_a?(Pathname) ? value : Pathname.new(value.to_s)
      end

      def normalize_artifact_paths(values)
        values.each_with_object({}) do |(key, value), normalized|
          normalized[key.to_sym] = pathname(value)
        end.freeze
      end
    end
  end
end
