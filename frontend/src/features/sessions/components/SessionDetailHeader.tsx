import { Link } from 'react-router'

import type { SessionDetail } from '../api/sessionApi.types.ts'
import {
  formatDegradedLabel,
  formatModel,
  formatTimestamp,
  formatWorkContext,
} from '../presentation/formatters.ts'

interface SessionDetailHeaderProps {
  detail: SessionDetail
}

function SessionDetailHeader({ detail }: SessionDetailHeaderProps) {
  return (
    <section className="rounded-3xl border border-white/10 bg-slate-900/70 p-6 shadow-2xl shadow-slate-950/20">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <div className="flex flex-wrap items-center gap-3">
            <h3 className="font-mono text-xl font-semibold text-cyan-200">{detail.id}</h3>
            <span
              className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${
                detail.degraded
                  ? 'bg-amber-400/15 text-amber-200 ring-1 ring-amber-300/25'
                  : 'bg-emerald-400/15 text-emerald-200 ring-1 ring-emerald-300/20'
              }`}
            >
              {formatDegradedLabel(detail.degraded)}
            </span>
          </div>

          <dl className="mt-4 grid gap-3 text-sm text-slate-300 sm:grid-cols-2">
            <div>
              <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                更新日時
              </dt>
              <dd className="mt-1">{formatTimestamp(detail.updated_at)}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                作業コンテキスト
              </dt>
              <dd className="mt-1">{formatWorkContext(detail.work_context)}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                モデル
              </dt>
              <dd className="mt-1">{formatModel(detail.selected_model)}</dd>
            </div>
          </dl>
        </div>

        <div className="shrink-0">
          <Link
            to="/"
            className="inline-flex items-center rounded-full border border-cyan-400/40 bg-cyan-400/10 px-4 py-2 text-sm font-medium text-cyan-100 transition hover:border-cyan-300 hover:bg-cyan-400/20"
          >
            セッション一覧へ戻る
          </Link>
        </div>
      </div>
    </section>
  )
}

export default SessionDetailHeader
