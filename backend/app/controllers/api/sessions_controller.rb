module Api
  class SessionsController < ApplicationController
    def index
      result = session_index_query.call

      case result
      when CopilotHistory::Types::ReadResult::Success
        render json: session_index_presenter.call(result: result), status: :ok
      when CopilotHistory::Types::ReadResult::Failure
        render_error(*error_presenter.from_read_failure(failure: result.failure))
      else
        raise ArgumentError, "unexpected session index result: #{result.class}"
      end
    end

    def show
      result = session_detail_query.call(session_id: params[:id])

      case result
      when CopilotHistory::Api::Types::SessionLookupResult::Found
        render json: session_detail_presenter.call(result: result, include_raw: include_raw?), status: :ok
      when CopilotHistory::Api::Types::SessionLookupResult::NotFound
        render_error(*error_presenter.from_not_found(session_id: result.session_id))
      when CopilotHistory::Types::ReadResult::Failure
        render_error(*error_presenter.from_read_failure(failure: result.failure))
      else
        raise ArgumentError, "unexpected session detail result: #{result.class}"
      end
    end

    private

    def render_error(status, payload)
      render json: payload, status: status
    end

    def session_index_query
      @session_index_query ||= CopilotHistory::Api::SessionIndexQuery.new
    end

    def session_detail_query
      @session_detail_query ||= CopilotHistory::Api::SessionDetailQuery.new
    end

    def session_index_presenter
      @session_index_presenter ||= CopilotHistory::Api::Presenters::SessionIndexPresenter.new
    end

    def session_detail_presenter
      @session_detail_presenter ||= CopilotHistory::Api::Presenters::SessionDetailPresenter.new
    end

    def error_presenter
      @error_presenter ||= CopilotHistory::Api::Presenters::ErrorPresenter.new
    end

    def include_raw?
      params[:include_raw] == "true"
    end
  end
end
