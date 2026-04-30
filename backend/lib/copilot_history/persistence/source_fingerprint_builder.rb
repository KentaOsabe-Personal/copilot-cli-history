module CopilotHistory
  module Persistence
    class SourceFingerprintBuilder
      OK = "ok"
      MISSING = "missing"
      UNREADABLE = "unreadable"

      def call(source_paths:)
        artifacts = source_paths
          .sort_by { |role, _path| role.to_s }
          .to_h { |role, path| [ role.to_s, artifact_metadata(path) ] }

        {
          "complete" => artifacts.values.all? { |artifact| artifact["status"] == OK },
          "artifacts" => artifacts
        }
      end

      private

      def artifact_metadata(path)
        pathname = Pathname.new(path.to_s)
        return unavailable_artifact(pathname, MISSING) unless pathname.exist?

        stat = pathname.stat

        {
          "path" => pathname.to_s,
          "mtime" => stat.mtime.utc.iso8601,
          "size" => stat.size,
          "status" => OK
        }
      rescue Errno::ENOENT
        unavailable_artifact(pathname, MISSING)
      rescue SystemCallError
        unavailable_artifact(pathname, UNREADABLE)
      end

      def unavailable_artifact(pathname, status)
        {
          "path" => pathname.to_s,
          "mtime" => nil,
          "size" => nil,
          "status" => status
        }
      end
    end
  end
end
