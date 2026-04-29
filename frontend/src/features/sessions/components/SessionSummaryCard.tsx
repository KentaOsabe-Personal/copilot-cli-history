import { Link } from 'react-router'

import type { SessionSummary } from '../api/sessionApi.types.ts'
import {
  formatDegradedLabel,
  formatModel,
  formatSourceStateLabel,
  formatTimestamp,
  formatWorkContext,
} from '../presentation/formatters.ts'

interface SessionSummaryCardProps {
  session: SessionSummary
}

function SessionSummaryCard({ session }: SessionSummaryCardProps) {
  const conversationLabel = session.conversation_summary.has_conversation
    ? '会話あり'
    : 'metadata-only'

  return (
    <article className="rounded-3xl border border-white/10 bg-slate-900/70 p-6 shadow-2xl shadow-slate-950/20">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-3">
            <h3 className="font-mono text-lg font-semibold text-cyan-200">{session.id}</h3>
            <span
              className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${
                session.conversation_summary.has_conversation
                  ? 'bg-cyan-400/15 text-cyan-100 ring-1 ring-cyan-300/20'
                  : 'bg-slate-700 text-slate-100 ring-1 ring-slate-600'
              }`}
            >
              {conversationLabel}
            </span>
            <span
              className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${
                session.degraded
                  ? 'bg-amber-400/15 text-amber-200 ring-1 ring-amber-300/25'
                  : 'bg-emerald-400/15 text-emerald-200 ring-1 ring-emerald-300/20'
              }`}
            >
              {formatDegradedLabel(session.degraded)}
            </span>
            <span className="inline-flex rounded-full bg-slate-800 px-3 py-1 text-xs font-semibold text-slate-200 ring-1 ring-slate-700">
              {formatSourceStateLabel(session.source_state)}
            </span>
          </div>

          <div className="mt-4 rounded-2xl border border-slate-700/70 bg-slate-950/30 p-4">
            <p className="text-sm font-medium text-white">
              {session.conversation_summary.preview ?? '表示できる会話本文はありません'}
            </p>
            <div className="mt-3 flex flex-wrap gap-2 text-xs font-semibold text-slate-300">
              <span className="rounded-full bg-slate-800 px-2.5 py-1">
                {`${session.conversation_summary.message_count} 件の会話`}
              </span>
              <span className="rounded-full bg-slate-800 px-2.5 py-1">
                {`${session.conversation_summary.activity_count} 件の内部 activity`}
              </span>
            </div>
          </div>

          <dl className="mt-4 grid gap-3 text-sm text-slate-300 sm:grid-cols-2">
            <div>
              <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                更新日時
              </dt>
              <dd className="mt-1">{formatTimestamp(session.updated_at)}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                作業コンテキスト
              </dt>
              <dd className="mt-1">{formatWorkContext(session.work_context)}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                モデル
              </dt>
              <dd className="mt-1">{formatModel(session.selected_model)}</dd>
            </div>
          </dl>
        </div>

        <div className="shrink-0">
          <Link
            to={`/sessions/${encodeURIComponent(session.id)}`}
            className="inline-flex items-center rounded-full border border-cyan-400/40 bg-cyan-400/10 px-4 py-2 text-sm font-medium text-cyan-100 transition hover:border-cyan-300 hover:bg-cyan-400/20"
            aria-label={`${session.id} を開く`}
          >
            詳細を開く
          </Link>
        </div>
      </div>
    </article>
  )
}

export default SessionSummaryCard
