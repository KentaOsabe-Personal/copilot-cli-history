import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import TimelineEntry from './TimelineEntry.tsx'

interface SessionTimelineProps {
  timeline: readonly SessionTimelineEvent[]
}

function SessionTimeline({ timeline }: SessionTimelineProps) {
  return (
    <section className="space-y-4">
      <h3 className="text-xl font-semibold text-white">タイムライン</h3>
      <ol className="space-y-4">
        {timeline.map((event) => (
          <TimelineEntry key={event.sequence} event={event} />
        ))}
      </ol>
    </section>
  )
}

export default SessionTimeline
