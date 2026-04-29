import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import { formatTimelineContent } from '../presentation/timelineContent.ts'

interface TimelineContentProps {
  event: Pick<SessionTimelineEvent, 'content' | 'tool_calls' | 'detail'>
}

function TimelineContent({ event }: TimelineContentProps) {
  const { blocks } = formatTimelineContent(event)

  if (blocks.length === 0) {
    return null
  }

  return (
    <div className="flex flex-col gap-3">
      {blocks.map((block, index) => {
        if (block.kind === 'tool_hint') {
          return (
            <section
              key={`tool-${index}`}
              className="rounded-2xl border border-cyan-400/30 bg-cyan-400/10 p-4 text-cyan-50"
            >
              <div className="flex flex-wrap items-center gap-2">
                <p className="text-xs font-semibold uppercase tracking-[0.24em] text-cyan-100/80">
                  ツール呼び出し
                </p>
                {block.status === 'partial' ? (
                  <span className="rounded-full border border-amber-300/40 bg-amber-300/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-amber-100">
                    partial
                  </span>
                ) : null}
                {block.isTruncated ? (
                  <span className="rounded-full border border-cyan-200/30 bg-cyan-50/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-cyan-50">
                    truncated
                  </span>
                ) : null}
              </div>
              <p className="mt-2 font-mono text-sm text-cyan-100">{block.name ?? 'unknown tool'}</p>
              {block.argumentsPreview != null ? (
                <pre className="mt-3 overflow-x-auto whitespace-pre-wrap rounded-xl bg-slate-950/50 p-3 text-xs text-cyan-50">
                  <code>{block.argumentsPreview}</code>
                </pre>
              ) : null}
            </section>
          )
        }

        if (block.kind === 'code') {
          return (
            <pre
              key={`code-${index}`}
              className="overflow-x-auto rounded-2xl border border-white/10 bg-slate-950/90 p-4 text-sm text-slate-100"
            >
              <code>{block.code}</code>
            </pre>
          )
        }

        if (block.kind === 'detail') {
          return (
            <section
              key={`detail-${index}`}
              className="rounded-2xl border border-slate-700 bg-slate-950/40 p-4 text-slate-100"
            >
              <p className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">
                詳細イベント
              </p>
              <div className="mt-2 flex flex-wrap items-center gap-2">
                <span className="rounded-full border border-slate-600 bg-slate-800/80 px-2.5 py-1 text-[11px] font-semibold text-slate-200">
                  {block.category}
                </span>
                <p className="text-sm font-medium text-slate-100">{block.title}</p>
              </div>
              {block.body != null ? (
                <p className="mt-3 whitespace-pre-wrap text-sm leading-6 text-slate-300">{block.body}</p>
              ) : null}
            </section>
          )
        }

        return (
          <p key={`text-${index}`} className="whitespace-pre-wrap text-sm leading-6 text-slate-100">
            {block.text}
          </p>
        )
      })}
    </div>
  )
}

export default TimelineContent
