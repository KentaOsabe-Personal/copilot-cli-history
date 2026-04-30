module CopilotHistory
  module Api
    module Presenters
      class HistorySyncPresenter
        HISTORY_SYNC_RUNNING_CODE = "history_sync_running"
        HISTORY_SYNC_RUNNING_MESSAGE = "history sync is already running"
        HISTORY_SYNC_FAILED_CODE = "history_sync_failed"

        def call(result:)
          case result
          when CopilotHistory::Sync::SyncResult::Succeeded
            [ :ok, success_payload(sync_run: result.sync_run) ]
          when CopilotHistory::Sync::SyncResult::Conflict
            [ :conflict, conflict_payload(running_run: result.running_run) ]
          when CopilotHistory::Sync::SyncResult::Failed
            failed_response(result:)
          else
            raise ArgumentError, "unsupported history sync result: #{result.class.name}"
          end
        end

        private

        def failed_response(result:)
          status = root_failure_code?(result.code) ? :service_unavailable : :internal_server_error
          details = result.details.dup
          details = details.merge(sync_run_id: result.sync_run.id) if status == :internal_server_error
          code = status == :internal_server_error ? HISTORY_SYNC_FAILED_CODE : result.code

          [
            status,
            {
              error: error_body(code:, message: result.message, details:),
              meta: run_meta(sync_run: result.sync_run)
            }
          ]
        end

        def success_payload(sync_run:)
          {
            data: {
              sync_run: present_sync_run(sync_run),
              counts: present_counts(sync_run)
            }
          }
        end

        def conflict_payload(running_run:)
          {
            error: error_body(
              code: HISTORY_SYNC_RUNNING_CODE,
              message: HISTORY_SYNC_RUNNING_MESSAGE,
              details: {
                sync_run_id: running_run.id,
                started_at: iso8601_or_nil(running_run.started_at)
              }
            )
          }
        end

        def run_meta(sync_run:)
          {
            sync_run: present_sync_run(sync_run),
            counts: present_counts(sync_run)
          }
        end

        def present_sync_run(sync_run)
          {
            id: sync_run.id,
            status: sync_run.status,
            started_at: iso8601_or_nil(sync_run.started_at),
            finished_at: iso8601_or_nil(sync_run.finished_at)
          }
        end

        def present_counts(sync_run)
          {
            processed_count: sync_run.processed_count,
            inserted_count: sync_run.inserted_count,
            updated_count: sync_run.updated_count,
            saved_count: sync_run.saved_count,
            skipped_count: sync_run.skipped_count,
            failed_count: sync_run.failed_count,
            degraded_count: sync_run.degraded_count
          }
        end

        def error_body(code:, message:, details:)
          {
            code:,
            message:,
            details:
          }
        end

        def root_failure_code?(code)
          CopilotHistory::Errors::ReadErrorCode::ROOT_FAILURE_CODES.include?(code)
        end

        def iso8601_or_nil(value)
          value&.iso8601
        end
      end
    end
  end
end
