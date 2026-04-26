require "json"
require "psych"

module CopilotHistory
  class CurrentSessionReader
    def initialize(event_normalizer_class: CopilotHistory::EventNormalizer)
      @event_normalizer_class = event_normalizer_class
    end

    def call(source)
      raise ArgumentError, "source format must be current" unless source.format == :current

      workspace_metadata, workspace_issues = read_workspace(source.artifact_paths.fetch(:workspace))
      events, event_issues = read_events(source)

      CopilotHistory::Types::NormalizedSession.new(
        session_id: workspace_metadata.fetch("session_id", source.session_id),
        source_format: :current,
        cwd: workspace_metadata["cwd"],
        git_root: workspace_metadata["git_root"],
        repository: workspace_metadata["repository"],
        branch: workspace_metadata["branch"],
        created_at: workspace_metadata["created_at"],
        updated_at: workspace_metadata["updated_at"],
        selected_model: nil,
        events: events,
        message_snapshots: [],
        issues: workspace_issues + event_issues,
        source_paths: source.artifact_paths
      )
    end

    private

    attr_reader :event_normalizer_class

    def read_workspace(workspace_path)
      return [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_UNREADABLE, "workspace.yaml is not accessible", workspace_path) ] ] unless readable_file?(workspace_path)

      payload = Psych.safe_load(workspace_path.read, permitted_classes: [], aliases: false)
      unless payload.is_a?(Hash)
        return [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_PARSE_FAILED, "workspace.yaml could not be parsed", workspace_path) ] ]
      end

      [ stringify_keys(payload), [] ]
    rescue Psych::Exception
      [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_PARSE_FAILED, "workspace.yaml could not be parsed", workspace_path) ] ]
    rescue SystemCallError
      [ {}, [ error_issue(CopilotHistory::Errors::ReadErrorCode::CURRENT_WORKSPACE_UNREADABLE, "workspace.yaml is not accessible", workspace_path) ] ]
    end

    def read_events(source)
      events_path = source.artifact_paths.fetch(:events)
      return [ [], [ error_issue(CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENTS_UNREADABLE, "events.jsonl is not accessible", events_path) ] ] unless readable_file?(events_path)

      normalizer = event_normalizer_class.new(source_path: events_path)
      events = []
      issues = []

      events_path.each_line.with_index(1) do |line, sequence|
        raw_event = JSON.parse(line)
        normalization_result = normalizer.call(
          raw_event: raw_event,
          source_format: source.format,
          sequence: sequence
        )

        events << normalization_result.event
        issues.concat(normalization_result.issues)
      rescue JSON::ParserError
        issues << error_issue(
          CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENT_PARSE_FAILED,
          "events.jsonl line could not be parsed",
          events_path,
          sequence: sequence
        )
      end

      [ events, issues ]
    rescue SystemCallError
      [ [].freeze, [ error_issue(CopilotHistory::Errors::ReadErrorCode::CURRENT_EVENTS_UNREADABLE, "events.jsonl is not accessible", events_path) ] ]
    end

    def error_issue(code, message, source_path, sequence: nil)
      CopilotHistory::Types::ReadIssue.new(
        code: code,
        message: message,
        source_path: source_path,
        sequence: sequence,
        severity: :error
      )
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

    def stringify_keys(hash)
      hash.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_s] = value
      end
    end
  end
end
