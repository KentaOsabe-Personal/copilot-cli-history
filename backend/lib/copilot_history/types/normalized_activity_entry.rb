module CopilotHistory
  module Types
    class NormalizedActivityEntry < Data.define(
      :sequence,
      :category,
      :title,
      :summary,
      :raw_type,
      :mapping_status,
      :occurred_at,
      :source_path,
      :raw_available,
      :degraded,
      :issues
    )
      def initialize(
        sequence:,
        category:,
        title:,
        summary:,
        raw_type:,
        mapping_status:,
        occurred_at:,
        source_path:,
        raw_available:,
        degraded:,
        issues:
      )
        super(
          sequence: Integer(sequence),
          category: category.to_s,
          title: title.to_s,
          summary: presence(summary),
          raw_type: raw_type.to_s,
          mapping_status: mapping_status.to_sym,
          occurred_at: normalize_time(occurred_at),
          source_path: pathname(source_path),
          raw_available: !!raw_available,
          degraded: !!degraded,
          issues: issues.freeze
        )
      end

      private

      def presence(value)
        return nil if value.nil?

        string_value = value.to_s
        string_value.empty? ? nil : string_value
      end

      def normalize_time(value)
        return value if value.nil? || value.is_a?(Time)

        Time.iso8601(value.to_s)
      end

      def pathname(value)
        return nil if value.nil?

        value.is_a?(Pathname) ? value : Pathname.new(value.to_s)
      end
    end
  end
end
