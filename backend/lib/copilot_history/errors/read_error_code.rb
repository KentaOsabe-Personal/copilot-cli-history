module CopilotHistory
  module Errors
    module ReadErrorCode
      ROOT_MISSING = "root_missing"
      ROOT_PERMISSION_DENIED = "root_permission_denied"
      ROOT_UNREADABLE = "root_unreadable"

      CURRENT_WORKSPACE_UNREADABLE = "current.workspace_unreadable"
      CURRENT_EVENTS_MISSING = "current.events_missing"
      CURRENT_EVENTS_UNREADABLE = "current.events_unreadable"
      CURRENT_WORKSPACE_PARSE_FAILED = "current.workspace_parse_failed"
      CURRENT_EVENT_PARSE_FAILED = "current.event_parse_failed"
      LEGACY_SOURCE_UNREADABLE = "legacy.source_unreadable"
      LEGACY_JSON_PARSE_FAILED = "legacy.json_parse_failed"
      EVENT_PARTIAL_MAPPING = "event.partial_mapping"
      EVENT_UNKNOWN_SHAPE = "event.unknown_shape"

      ROOT_FAILURE_CODES = [
        ROOT_MISSING,
        ROOT_PERMISSION_DENIED,
        ROOT_UNREADABLE
      ].freeze

      SESSION_ISSUE_CODES = [
        CURRENT_WORKSPACE_UNREADABLE,
        CURRENT_EVENTS_MISSING,
        CURRENT_EVENTS_UNREADABLE,
        CURRENT_WORKSPACE_PARSE_FAILED,
        CURRENT_EVENT_PARSE_FAILED,
        LEGACY_SOURCE_UNREADABLE,
        LEGACY_JSON_PARSE_FAILED,
        EVENT_PARTIAL_MAPPING,
        EVENT_UNKNOWN_SHAPE
      ].freeze

      ALL = (ROOT_FAILURE_CODES + SESSION_ISSUE_CODES).freeze
    end
  end
end
