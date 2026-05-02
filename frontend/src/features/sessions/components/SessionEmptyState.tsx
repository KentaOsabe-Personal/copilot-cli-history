import type { HistorySyncState } from '../hooks/useHistorySync.ts'
import StatusPanel from './StatusPanel.tsx'

interface SessionEmptyStateProps {
  syncState: HistorySyncState
  isSyncing: boolean
  onSync: () => void | Promise<void>
}

function SessionEmptyState({ syncState, isSyncing, onSync }: SessionEmptyStateProps) {
  const message =
    syncState.status === 'synced_empty'
      ? '履歴の取り込みは完了しましたが、表示できるセッションはまだありません。'
      : 'ローカルの Copilot CLI 履歴を取り込むと、ここから一覧を開けます。'

  return (
    <StatusPanel
      variant="empty"
      title="まだ表示できるセッションがありません"
      message={message}
      action={
        <button
          type="button"
          onClick={() => {
            void onSync()
          }}
          disabled={isSyncing}
          className="inline-flex items-center rounded-full border border-cyan-400/40 bg-cyan-400/10 px-4 py-2 text-sm font-medium text-cyan-100 transition hover:border-cyan-300 hover:bg-cyan-400/20 disabled:cursor-not-allowed disabled:border-cyan-400/20 disabled:bg-cyan-400/5 disabled:text-cyan-100/70"
        >
          {isSyncing ? '履歴を取り込み中...' : '履歴を取り込む'}
        </button>
      }
    />
  )
}

export default SessionEmptyState
