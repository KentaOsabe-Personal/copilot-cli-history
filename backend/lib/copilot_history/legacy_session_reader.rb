require "json"

module CopilotHistory
  class LegacySessionReader
    def initialize(event_normalizer_class: CopilotHistory::EventNormalizer)
      @event_normalizer_class = event_normalizer_class
    end

    def call(source)
      raise ArgumentError, "source format must be legacy" unless source.format == :legacy

      payload, issues = read_source(source.artifact_paths.fetch(:source))
      events = normalize_events(payload, source)
      message_snapshots = normalize_message_snapshots(payload)

      CopilotHistory::Types::NormalizedSession.new(
        session_id: payload.fetch("sessionId", source.session_id),
        source_format: :legacy,
        cwd: nil,
        git_root: nil,
        repository: nil,
        branch: nil,
        created_at: payload["startTime"],
        updated_at: nil,
        selected_model: payload["selectedModel"],
        events: events.fetch(:events),
        message_snapshots: message_snapshots,
        issues: issues + events.fetch(:issues),
        source_paths: source.artifact_paths
      )
    end

    private

    attr_reader :event_normalizer_class

    def read_source(source_path)
      return [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::LEGACY_SOURCE_UNREADABLE, "legacy session source is not accessible", source_path) ] ] unless readable_file?(source_path)

      payload = JSON.parse(source_path.read)
      unless payload.is_a?(Hash)
        return [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::LEGACY_JSON_PARSE_FAILED, "legacy session JSON could not be parsed", source_path) ] ]
      end

      [ stringify_keys(payload), [] ]
    rescue JSON::ParserError
      [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::LEGACY_JSON_PARSE_FAILED, "legacy session JSON could not be parsed", source_path) ] ]
    rescue SystemCallError
      [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::LEGACY_SOURCE_UNREADABLE, "legacy session source is not accessible", source_path) ] ]
    end

    def normalize_events(payload, source)
      source_path = source.artifact_paths.fetch(:source)
      normalizer = event_normalizer_class.new(source_path: source_path)
      events = []
      issues = []

      array_field(payload, "timeline").each_with_index do |entry, index|
        if entry.is_a?(Hash)
          normalization_result = normalizer.call(
            raw_event: stringify_keys(entry),
            source_format: source.format,
            sequence: index + 1
          )
          events << normalization_result.event
          issues.concat(normalization_result.issues)
        else
          events << unknown_event(entry, index + 1)
          issues << unknown_issue(source_path, index + 1)
        end
      end

      { events: events, issues: issues }
    end

    def normalize_message_snapshots(payload)
      array_field(payload, "chatMessages").map do |entry|
        normalized_entry = entry.is_a?(Hash) ? stringify_keys(entry) : entry

        CopilotHistory::Types::MessageSnapshot.new(
          role: value_or_nil(normalized_entry.is_a?(Hash) ? normalized_entry["role"] : nil),
          content: value_or_nil(normalized_entry.is_a?(Hash) ? normalized_entry["content"] : nil),
          raw_payload: normalized_entry
        )
      end
    end

    def unknown_event(entry, sequence)
      CopilotHistory::Types::NormalizedEvent.new(
        sequence: sequence,
        kind: :unknown,
        raw_type: entry.class.name.downcase,
        occurred_at: nil,
        role: nil,
        content: nil,
        raw_payload: entry
      )
    end

    def unknown_issue(source_path, sequence)
      CopilotHistory::Types::ReadIssue.new(
        code: CopilotHistory::Errors::ReadErrorCode::EVENT_UNKNOWN_SHAPE,
        message: "event payload could not be mapped to canonical fields",
        source_path: source_path,
        sequence: sequence,
        severity: :warning
      )
    end

    def error_issue(code, message, source_path)
      CopilotHistory::Types::ReadIssue.new(
        code: code,
        message: message,
        source_path: source_path,
        severity: :error
      )
    end

    def array_field(payload, key)
      value = payload[key]

      value.is_a?(Array) ? value : []
    end

    def value_or_nil(value)
      return nil if value.nil?

      string_value = value.to_s
      string_value.empty? ? nil : string_value
    end

    def readable_file?(path)
      stat = path.stat

      path.file? && readable_by_process?(stat)
    rescue SystemCallError
      false
    end

    def readable_by_process?(stat)
      mode = stat.mode

      if stat.uid == Process.euid
        (mode & 0o400).positive?
      elsif process_groups.include?(stat.gid)
        (mode & 0o040).positive?
      else
        (mode & 0o004).positive?
      end
    end

    def process_groups
      @process_groups ||= [ Process.egid, *Process.groups ].uniq.freeze
    end

    def stringify_keys(value)
      return value.each_with_object({}) { |(key, inner_value), normalized| normalized[key.to_s] = inner_value } if value.is_a?(Hash)

      {}
    end
  end
end
