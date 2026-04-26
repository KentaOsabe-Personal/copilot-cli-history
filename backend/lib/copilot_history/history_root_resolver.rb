module CopilotHistory
  class HistoryRootResolver
    def initialize(env: ENV)
      @env = env
    end

    def call
      root_path = resolved_root_path

      return failure(CopilotHistory::Errors::ReadErrorCode::ROOT_MISSING, root_path, "history root does not exist") unless root_path.exist?
      return failure(CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE, root_path, "history root is not a directory") unless root_path.directory?
      return failure(CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED, root_path, "history root is not accessible") unless accessible_directory?(root_path)

      CopilotHistory::Types::ResolvedHistoryRoot.new(
        root_path: root_path,
        current_root: root_path.join("session-state"),
        legacy_root: root_path.join("history-session-state")
      )
    rescue Errno::EACCES
      failure(CopilotHistory::Errors::ReadErrorCode::ROOT_PERMISSION_DENIED, root_path, "history root is not accessible")
    rescue SystemCallError
      failure(CopilotHistory::Errors::ReadErrorCode::ROOT_UNREADABLE, root_path, "history root is unreadable")
    end

    private

    attr_reader :env

    def resolved_root_path
      configured_root = env["COPILOT_HOME"]
      root = configured_root.nil? || configured_root.empty? ? "~/.copilot" : configured_root

      Pathname.new(root).expand_path
    end

    def failure(code, path, message)
      CopilotHistory::Types::ReadFailure.new(code:, path:, message:)
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
