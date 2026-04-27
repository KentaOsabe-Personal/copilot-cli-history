import { render, screen } from '@testing-library/react'

import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import TimelineContent from './TimelineContent.tsx'

function buildEvent(overrides: Partial<SessionTimelineEvent> = {}): SessionTimelineEvent {
  return {
    sequence: 1,
    kind: 'message',
    raw_type: 'assistant_message',
    occurred_at: '2026-04-26T09:00:02Z',
    role: 'assistant',
    content: 'hello\n```ts\nconst answer = 42\n```',
    raw_payload: {
      toolRequests: [
        {
          toolName: 'bash',
          arguments: {
            command: 'pwd',
          },
        },
      ],
    },
    degraded: false,
    issues: [],
    ...overrides,
  }
}

describe('TimelineContent', () => {
  it('renders text, code, and tool hint blocks with distinct labels', () => {
    render(<TimelineContent event={buildEvent()} />)

    expect(screen.getByText('bash')).toBeInTheDocument()
    expect(screen.getByText('hello')).toBeInTheDocument()
    expect(screen.getByText('const answer = 42')).toBeInTheDocument()
    expect(screen.getByText('ツール呼び出し')).toBeInTheDocument()
  })
})
