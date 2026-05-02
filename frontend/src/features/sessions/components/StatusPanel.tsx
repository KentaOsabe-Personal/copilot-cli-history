import type { ReactNode } from 'react'
import { Link } from 'react-router'

type StatusPanelVariant = 'loading' | 'empty' | 'not_found' | 'error'

interface StatusPanelProps {
  variant: StatusPanelVariant
  title: string
  message: string
  action?: ReactNode
  showSessionIndexLink?: boolean
  sessionIndexHref?: string
}

const VARIANT_STYLES: Record<StatusPanelVariant, string> = {
  loading: 'border-cyan-400/30 bg-cyan-400/10 text-cyan-50',
  empty: 'border-slate-600/70 bg-slate-900/70 text-slate-100',
  not_found: 'border-amber-400/30 bg-amber-400/10 text-amber-50',
  error: 'border-rose-400/30 bg-rose-400/10 text-rose-50',
}

function StatusPanel({
  variant,
  title,
  message,
  action,
  showSessionIndexLink = false,
  sessionIndexHref = '/',
}: StatusPanelProps) {
  return (
    <section className={`rounded-3xl border p-8 shadow-2xl ${VARIANT_STYLES[variant]}`}>
      <div className="flex flex-col gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-white/60">
            {variant.replace('_', ' ')}
          </p>
          <h2 className="mt-3 text-2xl font-semibold text-white">{title}</h2>
        </div>

        <p className="max-w-3xl text-sm leading-6 text-current/85">{message}</p>

        {action != null || showSessionIndexLink ? (
          <div className="flex flex-wrap items-center gap-3">
            {action != null ? <div>{action}</div> : null}
            {showSessionIndexLink ? (
              <Link
                to={sessionIndexHref}
                className="inline-flex items-center rounded-full border border-white/20 bg-white/10 px-4 py-2 text-sm font-medium text-white transition hover:border-white/40 hover:bg-white/15"
              >
                セッション一覧へ戻る
              </Link>
            ) : null}
          </div>
        ) : null}
      </div>
    </section>
  )
}

export default StatusPanel
