import { render, screen } from '@testing-library/react'

import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import TimelineContent from './TimelineContent.tsx'

function buildEvent(overrides: Partial<SessionTimelineEvent> = {}): SessionTimelineEvent {
  return {
    sequence: 1,
    kind: 'message',
    mapping_status: 'complete',
    raw_type: 'assistant_message',
    occurred_at: '2026-04-26T09:00:02Z',
    role: 'assistant',
    content: 'hello\n```ts\nconst answer = 42\n```',
    tool_calls: [
      {
        name: 'functions.bash',
        arguments_preview: '{"command":"pwd"}',
        is_truncated: false,
        status: 'complete',
      },
    ],
    detail: null,
    raw_payload: {},
    degraded: false,
    issues: [],
    ...overrides,
  }
}

describe('TimelineContent', () => {
  it('renders text, code, and tool hint blocks with distinct labels', () => {
    render(<TimelineContent event={buildEvent()} />)

    expect(screen.getByText('functions.bash')).toBeInTheDocument()
    expect(screen.getByText('hello')).toBeInTheDocument()
    expect(screen.getByText('const answer = 42')).toBeInTheDocument()
    expect(screen.getByText('ツール呼び出し')).toBeInTheDocument()
  })

  it('renders detail summaries as separate non-message blocks', () => {
    render(
      <TimelineContent
        event={buildEvent({
          kind: 'detail',
          role: null,
          content: null,
          tool_calls: [],
          detail: {
            category: 'tool_execution',
            title: 'tool.execution_start',
            body: 'functions.bash / tool-1',
          },
        })}
      />,
    )

    expect(screen.getByText('詳細イベント')).toBeInTheDocument()
    expect(screen.getByText('tool_execution')).toBeInTheDocument()
    expect(screen.getByText('tool.execution_start')).toBeInTheDocument()
    expect(screen.getByText('functions.bash / tool-1')).toBeInTheDocument()
  })
})
