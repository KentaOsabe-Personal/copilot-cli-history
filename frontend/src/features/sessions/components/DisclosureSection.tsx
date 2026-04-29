import { useId, useState, type ReactNode } from 'react'

interface DisclosureSectionProps {
  title: string
  summary: string
  count: number
  hasWarning?: boolean
  children: ReactNode
}

function DisclosureSection({
  title,
  summary,
  count,
  hasWarning = false,
  children,
}: DisclosureSectionProps) {
  const [expanded, setExpanded] = useState(false)
  const contentId = useId()

  return (
    <section className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/40 p-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-xl font-semibold text-white">{title}</h3>
            <span className="rounded-full border border-slate-600 bg-slate-900 px-3 py-1 text-xs font-semibold text-slate-200">
              {count} 件
            </span>
            {hasWarning ? (
              <span className="rounded-full border border-amber-300/40 bg-amber-300/10 px-3 py-1 text-xs font-semibold text-amber-100">
                警告あり
              </span>
            ) : null}
          </div>
          <p className="text-sm text-slate-400">{summary}</p>
        </div>

        <button
          type="button"
          className="rounded-full border border-white/15 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-100 transition hover:border-white/30 hover:bg-white/10"
          aria-controls={contentId}
          aria-expanded={expanded}
          onClick={() => {
            setExpanded((current) => !current)
          }}
        >
          {expanded ? `${title} を隠す` : `${title} を表示`}
        </button>
      </div>

      <div id={contentId} hidden={!expanded}>
        {expanded ? children : null}
      </div>
    </section>
  )
}

export default DisclosureSection
