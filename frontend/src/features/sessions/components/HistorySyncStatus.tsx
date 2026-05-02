import type { HistorySyncCounts, SessionApiError } from '../api/sessionApi.types.ts'
import type { HistorySyncState } from '../hooks/useHistorySync.ts'

type StatusTone = 'success' | 'info' | 'warning' | 'error'

interface BannerContent {
  tone: StatusTone
  role: 'status' | 'alert'
  eyebrow: string
  title: string
  message: string
}

const TONE_STYLES: Record<StatusTone, string> = {
  success: 'border-emerald-400/30 bg-emerald-400/10 text-emerald-50',
  info: 'border-slate-600/70 bg-slate-900/70 text-slate-100',
  warning: 'border-amber-400/30 bg-amber-400/10 text-amber-50',
  error: 'border-rose-400/30 bg-rose-400/10 text-rose-50',
}

interface HistorySyncStatusProps {
  state: HistorySyncState
}

function HistorySyncStatus({ state }: HistorySyncStatusProps) {
  const content = toBannerContent(state)

  if (content == null) {
    return null
  }

  return (
    <section
      role={content.role}
      aria-live="polite"
      className={`rounded-3xl border p-6 shadow-2xl ${TONE_STYLES[content.tone]}`}
    >
      <p className="text-xs font-semibold uppercase tracking-[0.24em] text-current/70">
        {content.eyebrow}
      </p>
      <h3 className="mt-3 text-lg font-semibold text-white">{content.title}</h3>
      <p className="mt-3 text-sm leading-6 text-current/85">{content.message}</p>
    </section>
  )
}

function toBannerContent(state: HistorySyncState): BannerContent | null {
  switch (state.status) {
    case 'idle':
    case 'syncing':
      return null
    case 'synced_with_sessions':
      return {
        tone: 'success',
        role: 'status',
        eyebrow: 'sync complete',
        title: '履歴を最新化しました',
        message: buildSavedCountsMessage(state.result.counts),
      }
    case 'synced_empty':
      return {
        tone: 'info',
        role: 'status',
        eyebrow: 'sync complete',
        title: '履歴の同期は完了しました',
        message: '取り込みは完了しましたが、表示できるセッションはまだありません。',
      }
    case 'refresh_error':
      return {
        tone: 'warning',
        role: 'alert',
        eyebrow: 'refresh required',
        title: '履歴の同期は完了しましたが、最新の一覧を表示できません',
        message: `${buildSavedCountForContinuation(state.result.counts)}が、一覧の再取得に失敗しました。時間をおいて再度お試しください。`,
      }
    case 'conflict':
      return {
        tone: 'warning',
        role: 'alert',
        eyebrow: 'sync pending',
        title: '履歴同期はすでに進行中の可能性があります',
        message: '少し時間をおいてから、もう一度お試しください。',
      }
    case 'sync_error':
      return {
        tone: 'error',
        role: 'alert',
        eyebrow: 'sync failed',
        title: '履歴を同期できませんでした',
        message: buildRetryGuidance(state.error),
      }
  }
}

function buildSavedCountsMessage(counts: HistorySyncCounts): string {
  const baseMessage = buildSavedCountOnly(counts)

  if (counts.degraded_count === 0) {
    return baseMessage
  }

  return `${baseMessage}${counts.degraded_count} 件は一部欠損を含みます。`
}

function buildSavedCountOnly(counts: HistorySyncCounts): string {
  return `${counts.saved_count} 件を保存しました。`
}

function buildSavedCountForContinuation(counts: HistorySyncCounts): string {
  return `${counts.saved_count} 件を保存しました`
}

function buildRetryGuidance(error: SessionApiError): string {
  switch (error.kind) {
    case 'network':
      return 'ネットワーク接続を確認してから再試行してください。'
    case 'config':
      return 'API 接続先の設定を確認してから再試行してください。'
    case 'not_found':
    case 'backend':
      return 'backend の状態を確認してから再試行してください。'
  }
}

export default HistorySyncStatus
