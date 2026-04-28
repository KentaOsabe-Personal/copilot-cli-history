module CopilotHistory
  class EventNormalizer
    VALID_SOURCE_FORMATS = %i[current legacy].freeze
    LEGACY_MESSAGE_TYPES = %w[user_message assistant_message system_message].freeze
    CURRENT_MESSAGE_TYPES = %w[user.message assistant.message system.message].freeze
    TOOL_ARGUMENT_PREVIEW_LIMIT = 240
    REDACTED_ARGUMENT_KEYS = %w[token secret password authorization cookie].freeze
    DETAIL_CATEGORIES = {
      /\Aassistant\.turn_/ => "assistant_turn",
      /\Atool\.execution_/ => "tool_execution",
      /\Ahook\./ => "hook",
      /\Askill\.invoked\z/ => "skill"
    }.freeze

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

      return unknown_result(payload:, raw_type:, sequence:) unless payload.is_a?(Hash)

      case normalized_source_format
      when :current
        normalize_current_event(payload:, raw_type:, sequence:)
      when :legacy
        normalize_legacy_event(payload:, raw_type:, sequence:)
      end
    end

    private

    attr_reader :source_path

    def normalize_legacy_event(payload:, raw_type:, sequence:)
      return unknown_result(payload:, raw_type:, sequence:) unless LEGACY_MESSAGE_TYPES.include?(raw_type)

      role = presence(payload["role"])
      content = presence(payload["content"])
      occurred_at = parse_time(payload["timestamp"])

      issues = []
      mapping_status = :complete

      if role.nil? || content.nil? || timestamp_missing_or_invalid?(payload)
        mapping_status = :partial
        issues << issue(
          code: CopilotHistory::Errors::ReadErrorCode::EVENT_PARTIAL_MAPPING,
          message: "event payload matched partially",
          sequence: sequence
        )
      end

      CopilotHistory::Types::NormalizationResult.new(
        event: CopilotHistory::Types::NormalizedEvent.new(
          sequence: sequence,
          kind: :message,
          mapping_status: mapping_status,
          raw_type: raw_type,
          occurred_at: occurred_at,
          role: role,
          content: content,
          tool_calls: [],
          detail: nil,
          raw_payload: payload
        ),
        issues: issues
      )
    end

    def normalize_current_event(payload:, raw_type:, sequence:)
      return normalize_current_message(payload:, raw_type:, sequence:) if CURRENT_MESSAGE_TYPES.include?(raw_type)
      return normalize_legacy_event(payload:, raw_type:, sequence:) if LEGACY_MESSAGE_TYPES.include?(raw_type)

      category = detail_category_for(raw_type)
      return normalize_current_detail(payload:, raw_type:, sequence:, category:) unless category.nil?

      unknown_result(payload:, raw_type:, sequence:)
    end

    def normalize_current_message(payload:, raw_type:, sequence:)
      data = payload["data"].is_a?(Hash) ? payload["data"] : {}
      role = presence(data["role"]) || role_from_current_type(raw_type)
      content = presence(data["content"])
      occurred_at = parse_time(payload["timestamp"])
      tool_calls, tool_call_partial = extract_tool_calls(data["toolRequests"])

      issues = []
      mapping_status = :complete

      if role.nil? || content.nil? || timestamp_missing_or_invalid?(payload) || tool_call_partial
        mapping_status = :partial
        issues << partial_mapping_issue(sequence:)
      end

      CopilotHistory::Types::NormalizationResult.new(
        event: CopilotHistory::Types::NormalizedEvent.new(
          sequence: sequence,
          kind: :message,
          mapping_status: mapping_status,
          raw_type: raw_type,
          occurred_at: occurred_at,
          role: role,
          content: content,
          tool_calls: tool_calls,
          detail: nil,
          raw_payload: payload
        ),
        issues: issues
      )
    end

    def normalize_current_detail(payload:, raw_type:, sequence:, category:)
      CopilotHistory::Types::NormalizationResult.new(
        event: CopilotHistory::Types::NormalizedEvent.new(
          sequence: sequence,
          kind: :detail,
          mapping_status: timestamp_missing_or_invalid?(payload) ? :partial : :complete,
          raw_type: raw_type,
          occurred_at: parse_time(payload["timestamp"]),
          role: nil,
          content: nil,
          tool_calls: [],
          detail: {
            category: category,
            title: raw_type,
            body: detail_body_for(raw_type:, data: payload["data"])
          },
          raw_payload: payload
        ),
        issues: timestamp_missing_or_invalid?(payload) ? [ partial_mapping_issue(sequence:) ] : []
      )
    end

    def unknown_result(payload:, raw_type:, sequence:)
      CopilotHistory::Types::NormalizationResult.new(
        event: CopilotHistory::Types::NormalizedEvent.new(
          sequence: sequence,
          kind: :unknown,
          mapping_status: :complete,
          raw_type: raw_type,
          occurred_at: nil,
          role: nil,
          content: nil,
          tool_calls: [],
          detail: nil,
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

    def extract_tool_calls(raw_tool_requests)
      return [ [], false ] if raw_tool_requests.nil?
      return [ [], true ] unless raw_tool_requests.is_a?(Array)

      partial = false
      tool_calls = raw_tool_requests.map do |tool_request|
        request = normalize_payload(tool_request)
        unless request.is_a?(Hash)
          partial = true
          next CopilotHistory::Types::NormalizedToolCall.new(
            name: nil,
            arguments_preview: nil,
            is_truncated: false,
            status: :partial
          )
        end

        name = presence(request["name"])
        arguments_preview, is_truncated, preview_missing = arguments_preview_for(request["arguments"])
        status = if name.nil? || preview_missing
          partial = true
          :partial
        else
          :complete
        end

        CopilotHistory::Types::NormalizedToolCall.new(
          name: name,
          arguments_preview: arguments_preview,
          is_truncated: is_truncated,
          status: status
        )
      end

      [ tool_calls, partial ]
    end

    def arguments_preview_for(arguments)
      return [ nil, false, true ] if arguments.nil?

      preview = JSON.generate(redact_sensitive_arguments(arguments))
      return [ preview, false, false ] if preview.length <= TOOL_ARGUMENT_PREVIEW_LIMIT

      [ preview[0, TOOL_ARGUMENT_PREVIEW_LIMIT], true, false ]
    rescue JSON::GeneratorError
      stringified = arguments.to_s
      return [ nil, false, true ] if stringified.empty?
      return [ stringified, false, false ] if stringified.length <= TOOL_ARGUMENT_PREVIEW_LIMIT

      [ stringified[0, TOOL_ARGUMENT_PREVIEW_LIMIT], true, false ]
    end

    def redact_sensitive_arguments(value, parent_key = nil)
      if redact_key?(parent_key)
        "[REDACTED]"
      elsif value.is_a?(Hash)
        value.each_with_object({}) do |(key, child_value), normalized|
          normalized[key.to_s] = redact_sensitive_arguments(child_value, key.to_s)
        end
      elsif value.is_a?(Array)
        value.map { |child_value| redact_sensitive_arguments(child_value, parent_key) }
      else
        value
      end
    end

    def redact_key?(key)
      return false if key.nil?

      lowered_key = key.to_s.downcase
      REDACTED_ARGUMENT_KEYS.any? { |candidate| lowered_key.include?(candidate) }
    end

    def detail_category_for(raw_type)
      DETAIL_CATEGORIES.each do |pattern, category|
        return category if pattern.match?(raw_type)
      end

      nil
    end

    def detail_body_for(raw_type:, data:)
      normalized_data = data.is_a?(Hash) ? data : {}

      case detail_category_for(raw_type)
      when "assistant_turn"
        presence(normalized_data["turnId"])
      when "tool_execution"
        [ presence(normalized_data["toolName"]), presence(normalized_data["toolCallId"]) ].compact.join(" / ")
      when "hook"
        [ presence(normalized_data["hookEventName"]), presence(normalized_data["matcher"]) ].compact.join(" / ")
      when "skill"
        [ presence(normalized_data["skillName"]), presence(normalized_data["toolName"]) ].compact.join(" / ")
      end
    end

    def role_from_current_type(raw_type)
      prefix = raw_type.to_s.split(".", 2).first
      %w[user assistant system].include?(prefix) ? prefix : nil
    end

    def partial_mapping_issue(sequence:)
      issue(
        code: CopilotHistory::Errors::ReadErrorCode::EVENT_PARTIAL_MAPPING,
        message: "event payload matched partially",
        sequence: sequence
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
        normalized[key.to_s] = normalize_payload(value)
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
