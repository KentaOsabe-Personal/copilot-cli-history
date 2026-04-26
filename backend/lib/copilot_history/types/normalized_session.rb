module CopilotHistory
  module Types
    class NormalizedSession < Data.define(
      :session_id,
      :source_format,
      :cwd,
      :git_root,
      :repository,
      :branch,
      :created_at,
      :updated_at,
      :selected_model,
      :events,
      :message_snapshots,
      :issues,
      :source_paths
    )
      VALID_FORMATS = %i[current legacy].freeze

      def initialize(
        session_id:,
        source_format:,
        cwd: nil,
        git_root: nil,
        repository: nil,
        branch: nil,
        created_at: nil,
        updated_at: nil,
        selected_model: nil,
        events:,
        message_snapshots:,
        issues:,
        source_paths:
      )
        normalized_format = source_format.to_sym
        raise ArgumentError, "source_format must be one of: #{VALID_FORMATS.join(", ")}" unless VALID_FORMATS.include?(normalized_format)

        super(
          session_id: session_id,
          source_format: normalized_format,
          cwd: normalize_path(cwd),
          git_root: normalize_path(git_root),
          repository: repository,
          branch: branch,
          created_at: normalize_time(created_at),
          updated_at: normalize_time(updated_at),
          selected_model: selected_model,
          events: events.freeze,
          message_snapshots: message_snapshots.freeze,
          issues: issues.freeze,
          source_paths: normalize_source_paths(source_paths)
        )
      end

      private

      def normalize_path(value)
        return value if value.nil? || value.is_a?(Pathname)

        Pathname.new(value.to_s)
      end

      def normalize_time(value)
        return value if value.nil? || value.is_a?(Time)

        Time.iso8601(value.to_s)
      end

      def normalize_source_paths(values)
        values.each_with_object({}) do |(key, value), normalized|
          normalized[key.to_sym] = normalize_path(value)
        end.freeze
      end
    end
  end
end
