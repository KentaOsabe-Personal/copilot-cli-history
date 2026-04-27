module CopilotHistory
  class SessionCatalogReader
    def initialize(
      root_resolver: CopilotHistory::HistoryRootResolver.new,
      source_catalog: CopilotHistory::SessionSourceCatalog.new,
      current_session_reader: CopilotHistory::CurrentSessionReader.new,
      legacy_session_reader: CopilotHistory::LegacySessionReader.new,
      logger: Rails.logger
    )
      @root_resolver = root_resolver
      @source_catalog = source_catalog
      @current_session_reader = current_session_reader
      @legacy_session_reader = legacy_session_reader
      @logger = logger
    end

    def call
      resolved_root = root_resolver.call
      return root_failure_result(resolved_root) if resolved_root.is_a?(CopilotHistory::Types::ReadFailure)

      sessions = source_catalog.call(resolved_root).map do |source|
        read_session(source)
      end

      CopilotHistory::Types::ReadResult::Success.new(root: resolved_root, sessions: sessions)
    rescue CopilotHistory::SessionSourceCatalog::SourceAccessError => error
      root_failure_result(error.failure)
    end

    private

    attr_reader :root_resolver, :source_catalog, :current_session_reader, :legacy_session_reader, :logger

    def root_failure_result(failure)
      logger&.error(log_payload(source_path: failure.path, failure_code: failure.code))

      CopilotHistory::Types::ReadResult::Failure.new(failure: failure)
    end

    def read_session(source)
      case source.format
      when :current
        current_session_reader.call(source)
      when :legacy
        legacy_session_reader.call(source)
      else
        raise ArgumentError, "unsupported session source format: #{source.format.inspect}"
      end
    end

    def log_payload(source_path: nil, failure_code: nil)
      {
        source_path: source_path&.to_s,
        failure_code: failure_code
      }
    end
  end
end
