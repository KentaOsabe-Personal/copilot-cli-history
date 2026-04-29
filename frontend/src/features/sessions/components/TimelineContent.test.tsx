import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

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

  it('collapses long tool arguments by default while keeping tool metadata visible', () => {
    render(
      <TimelineContent
        event={buildEvent({
          tool_calls: [
            {
              name: 'skill-context',
              arguments_preview: 'line one\nline two',
              is_truncated: true,
              status: 'partial',
            },
          ],
        })}
      />,
    )

    const toolBlock = screen.getByRole('group', { name: 'tool call skill-context' })

    expect(within(toolBlock).getByText('skill-context')).toBeInTheDocument()
    expect(within(toolBlock).getByText('partial')).toBeInTheDocument()
    expect(within(toolBlock).getByText('truncated')).toBeInTheDocument()
    expect(within(toolBlock).getByRole('button', { name: 'arguments を表示' })).toBeInTheDocument()
    expect(within(toolBlock).queryByText('line one\nline two')).not.toBeInTheDocument()
  })

  it('reveals collapsed arguments inside the same tool block', async () => {
    const user = userEvent.setup()

    render(
      <TimelineContent
        event={buildEvent({
          tool_calls: [
            {
              name: 'functions.bash',
              arguments_preview: 'echo one\necho two',
              is_truncated: false,
              status: 'complete',
            },
          ],
        })}
      />,
    )

    const toolBlock = screen.getByRole('group', { name: 'tool call functions.bash' })

    expect(within(toolBlock).queryByText('echo one\necho two')).not.toBeInTheDocument()

    await user.click(within(toolBlock).getByRole('button', { name: 'arguments を表示' }))

    expect(toolBlock).toHaveTextContent(/echo one\s+echo two/)
    expect(within(toolBlock).getByText('functions.bash')).toBeInTheDocument()
    expect(within(toolBlock).getByText('ツール呼び出し')).toBeInTheDocument()
  })

  it('does not render an arguments toggle when a tool call has no arguments preview', () => {
    render(
      <TimelineContent
        event={buildEvent({
          content: null,
          tool_calls: [
            {
              name: 'functions.read',
              arguments_preview: null,
              is_truncated: false,
              status: 'complete',
            },
          ],
        })}
      />,
    )

    const toolBlock = screen.getByRole('group', { name: 'tool call functions.read' })

    expect(within(toolBlock).getByText('functions.read')).toBeInTheDocument()
    expect(within(toolBlock).queryByRole('button')).not.toBeInTheDocument()
  })
})
