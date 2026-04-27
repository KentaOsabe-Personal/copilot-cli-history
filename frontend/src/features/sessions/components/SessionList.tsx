import type { SessionSummary } from '../api/sessionApi.types.ts'
import SessionSummaryCard from './SessionSummaryCard.tsx'

interface SessionListProps {
  sessions: readonly SessionSummary[]
}

function SessionList({ sessions }: SessionListProps) {
  return (
    <div className="grid gap-4">
      {sessions.map((session) => (
        <SessionSummaryCard key={session.id} session={session} />
      ))}
    </div>
  )
}

export default SessionList
