module CopilotHistory
  class EventNormalizer
    VALID_SOURCE_FORMATS = %i[current legacy].freeze
    MESSAGE_TYPES = %w[user_message assistant_message].freeze

    def initialize(source_path:)
      @source_path = source_path.is_a?(Pathname) ? source_path : Pathname.new(source_path.to_s)
    end

    def call(raw_event:, source_format:, sequence:)
      normalized_source_format = source_format.to_sym
      unless VALID_SOURCE_FORMATS.include?(normalized_source_format)
        raise ArgumentError, "source_format must be one of: #{VALID_SOURCE_FORMATS.join(", ")}"
      end

      payload = normalize_payload(raw_event)
      raw_type = extract_raw_type(payload, raw_event)

      return unknown_result(payload:, raw_type:, sequence:) unless payload.is_a?(Hash) && MESSAGE_TYPES.include?(raw_type)

      normalize_message(payload:, raw_type:, sequence:)
    end

    private

    attr_reader :source_path

    def normalize_message(payload:, raw_type:, sequence:)
      role = presence(payload["role"])
      content = presence(payload["content"])
      occurred_at = parse_time(payload["timestamp"])

      issues = []
      kind = :message

      if role.nil? || content.nil? || timestamp_missing_or_invalid?(payload)
        kind = :partial
        issues << issue(
          code: CopilotHistory::Errors::ReadErrorCode::EVENT_PARTIAL_MAPPING,
          message: "event payload matched partially",
          sequence: sequence
        )
      end

      CopilotHistory::Types::NormalizationResult.new(
        event: CopilotHistory::Types::NormalizedEvent.new(
          sequence: sequence,
          kind: kind,
          raw_type: raw_type,
          occurred_at: occurred_at,
          role: role,
          content: content,
          raw_payload: payload
        ),
        issues: issues
      )
    end

    def unknown_result(payload:, raw_type:, sequence:)
      CopilotHistory::Types::NormalizationResult.new(
        event: CopilotHistory::Types::NormalizedEvent.new(
          sequence: sequence,
          kind: :unknown,
          raw_type: raw_type,
          occurred_at: nil,
          role: nil,
          content: nil,
          raw_payload: payload
        ),
        issues: [
          issue(
            code: CopilotHistory::Errors::ReadErrorCode::EVENT_UNKNOWN_SHAPE,
            message: "event payload could not be mapped to canonical fields",
            sequence: sequence
          )
        ]
      )
    end

    def issue(code:, message:, sequence:)
      CopilotHistory::Types::ReadIssue.new(
        code: code,
        message: message,
        source_path: source_path,
        sequence: sequence,
        severity: :warning
      )
    end

    def stringify_keys(raw_event)
      raw_event.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_s] = value
      end
    end

    def normalize_payload(raw_event)
      raw_event.is_a?(Hash) ? stringify_keys(raw_event) : raw_event
    end

    def extract_raw_type(payload, raw_event)
      return payload["type"].to_s if payload.is_a?(Hash)

      raw_event.class.name.downcase
    end

    def presence(value)
      return nil if value.nil?

      string_value = value.to_s
      string_value.empty? ? nil : string_value
    end

    def parse_time(value)
      return nil if value.nil?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def timestamp_missing_or_invalid?(payload)
      return true unless payload.key?("timestamp")
      return true if payload["timestamp"].nil?

      parse_time(payload["timestamp"]).nil?
    end
  end
end
