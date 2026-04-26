module CopilotHistory
  class SessionSourceCatalog
    def call(root)
      current_sources(root.current_root) + legacy_sources(root.legacy_root)
    end

    private

    def current_sources(current_root)
      return [] unless current_root.directory?

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
    end

    def legacy_sources(legacy_root)
      return [] unless legacy_root.directory?

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
    end
  end
end
