module CopilotHistory
  class SessionSourceCatalog
    class SourceAccessError < StandardError
      attr_reader :failure

      def initialize(failure)
        @failure = failure
        super(failure.message)
      end
    end

    def call(root)
      current_sources(root.current_root) + legacy_sources(root.legacy_root)
    end

    private

    def current_sources(current_root)
      return [] unless current_root.exist?

      ensure_accessible_directory!(current_root)

      current_root.children
        .select(&:directory?)
        .sort_by { |path| path.basename.to_s }
        .map do |session_directory|
          session_id = session_directory.basename.to_s

          CopilotHistory::Types::SessionSource.new(
            format: :current,
            session_id: session_id,
            source_path: session_directory,
            artifact_paths: {
              workspace: session_directory.join("workspace.yaml"),
              events: session_directory.join("events.jsonl")
            }
          )
        end
    rescue SourceAccessError
      raise
    rescue SystemCallError
      raise access_error(
        code: CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE,
        path: current_root,
        message: "history source directory is unreadable"
      )
    end

    def legacy_sources(legacy_root)
      return [] unless legacy_root.exist?

      ensure_accessible_directory!(legacy_root)

      legacy_root.glob("*.json")
        .sort_by { |path| path.basename.to_s }
        .map do |source_path|
          CopilotHistory::Types::SessionSource.new(
            format: :legacy,
            session_id: source_path.basename(".json").to_s,
            source_path: source_path,
            artifact_paths: { source: source_path }
          )
        end
    rescue SourceAccessError
      raise
    rescue SystemCallError
      raise access_error(
        code: CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE,
        path: legacy_root,
        message: "history source directory is unreadable"
      )
    end

    def ensure_accessible_directory!(path)
      unless path.directory?
        raise access_error(
          code: CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE,
          path: path,
          message: "history source directory is not a directory"
        )
      end

      return if accessible_directory?(path)

      raise access_error(
        code: CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED,
        path: path,
        message: "history source directory is not accessible"
      )
    rescue Errno::EACCES
      raise access_error(
        code: CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED,
        path: path,
        message: "history source directory is not accessible"
      )
    rescue SystemCallError
      raise access_error(
        code: CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE,
        path: path,
        message: "history source directory is unreadable"
      )
    end

    def access_error(code:, path:, message:)
      SourceAccessError.new(
        CopilotHistory::Types::ReadFailure.new(
          code: code,
          path: path,
          message: message
        )
      )
    end

    def accessible_directory?(path)
      stat = path.stat

      readable_by_process?(stat) && executable_by_process?(stat)
    end

    def readable_by_process?(stat)
      permission_granted?(stat, owner: 0o400, group: 0o040, other: 0o004)
    end

    def executable_by_process?(stat)
      permission_granted?(stat, owner: 0o100, group: 0o010, other: 0o001)
    end

    def permission_granted?(stat, owner:, group:, other:)
      mode = stat.mode

      if stat.uid == Process.euid
        (mode & owner).positive?
      elsif process_groups.include?(stat.gid)
        (mode & group).positive?
      else
        (mode & other).positive?
      end
    end

    def process_groups
      @process_groups ||= [ Process.egid, *Process.groups ].uniq.freeze
    end
  end
end
