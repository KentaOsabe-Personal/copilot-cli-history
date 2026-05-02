interface HistorySyncControlProps {
  isSyncing: boolean
  onSync: () => void | Promise<void>
}

function HistorySyncControl({ isSyncing, onSync }: HistorySyncControlProps) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-3xl border border-slate-800 bg-slate-950/40 p-4">
      <div className="min-w-0">
        <h3 className="text-sm font-semibold text-white">履歴の手動同期</h3>
        <p className="mt-1 text-sm text-slate-300">
          必要なときだけ履歴を最新化します。自動では同期されません。
        </p>
      </div>

      <button
        type="button"
        onClick={() => {
          void onSync()
        }}
        disabled={isSyncing}
        aria-busy={isSyncing}
        className="inline-flex items-center rounded-full border border-cyan-400/40 bg-cyan-400/10 px-4 py-2 text-sm font-medium text-cyan-100 transition hover:border-cyan-300 hover:bg-cyan-400/20 disabled:cursor-not-allowed disabled:border-cyan-400/20 disabled:bg-cyan-400/5 disabled:text-cyan-100/70"
      >
        {isSyncing ? '履歴を同期中...' : '履歴を最新化'}
      </button>
    </div>
  )
}

export default HistorySyncControl
