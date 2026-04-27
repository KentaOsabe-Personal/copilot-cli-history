import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import { formatTimelineContent } from '../presentation/timelineContent.ts'

interface TimelineContentProps {
  event: SessionTimelineEvent
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
              <p className="text-xs font-semibold uppercase tracking-[0.24em] text-cyan-100/80">
                ツール呼び出し
              </p>
              <p className="mt-2 font-mono text-sm text-cyan-100">{block.name}</p>
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
