import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import { formatTimestamp } from '../presentation/formatters.ts'
import IssueList from './IssueList.tsx'
import TimelineContent from './TimelineContent.tsx'

interface TimelineEntryProps {
  event: SessionTimelineEvent
}

function TimelineEntry({ event }: TimelineEntryProps) {
  return (
    <li className="rounded-3xl border border-white/10 bg-slate-900/70 p-6 shadow-2xl shadow-slate-950/20">
      <div className="flex flex-wrap items-center gap-2">
        <h4 className="text-lg font-semibold text-white">{`イベント #${event.sequence}`}</h4>
        <span className="rounded-full bg-slate-800 px-2.5 py-1 text-xs font-semibold text-slate-100">
          {event.kind}
        </span>
        {event.role != null ? (
          <span className="rounded-full bg-cyan-400/10 px-2.5 py-1 text-xs font-semibold text-cyan-100">
            {event.role}
          </span>
        ) : null}
      </div>

      <dl className="mt-4 grid gap-3 text-sm text-slate-300 sm:grid-cols-2">
        <div>
          <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">発生時刻</dt>
          <dd className="mt-1">{formatTimestamp(event.occurred_at)}</dd>
        </div>
        {event.raw_type != null ? (
          <div>
            <dt className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
              Raw Type
            </dt>
            <dd className="mt-1">{event.raw_type}</dd>
          </div>
        ) : null}
      </dl>

      <div className="mt-4">
        <TimelineContent event={event} />
      </div>

      <div className="mt-4">
        <IssueList title="イベントの issue" issues={event.issues} />
      </div>
    </li>
  )
}

export default TimelineEntry
