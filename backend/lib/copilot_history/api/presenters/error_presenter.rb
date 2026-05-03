module CopilotHistory
  module Api
    module Presenters
      class ErrorPresenter
        SESSION_NOT_FOUND_CODE = "session_not_found"
        SESSION_NOT_FOUND_MESSAGE = "session was not found"

        def from_read_failure(failure:)
          [ :service_unavailable, error_payload(code: failure.code, message: failure.message, details: { path: failure.path.to_s }) ]
        end

        def from_not_found(session_id:)
          [ :not_found, error_payload(code: SESSION_NOT_FOUND_CODE, message: SESSION_NOT_FOUND_MESSAGE, details: { session_id: }) ]
        end

        def from_invalid_session_list_query(invalid_result:)
          [
            :bad_request,
            error_payload(
              code: invalid_result.code,
              message: invalid_result.message,
              details: invalid_result.details
            )
          ]
        end

        private

        def error_payload(code:, message:, details:)
          {
            error: {
              code:,
              message:,
              details:
            }
          }
        end
      end
    end
  end
end
