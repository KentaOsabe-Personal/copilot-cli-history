module Api
  class HistorySyncsController < ApplicationController
    def create
      status, payload = history_sync_presenter.call(result: history_sync_service.call)

      render json: payload, status: status
    end

    private

    def history_sync_service
      @history_sync_service ||= CopilotHistory::Sync::HistorySyncService.new
    end

    def history_sync_presenter
      @history_sync_presenter ||= CopilotHistory::Api::Presenters::HistorySyncPresenter.new
    end
  end
end
