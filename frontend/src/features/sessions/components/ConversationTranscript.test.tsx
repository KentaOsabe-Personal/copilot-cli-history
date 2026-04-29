import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'

import type { SessionConversation } from '../api/sessionApi.types.ts'
import ConversationTranscript from './ConversationTranscript.tsx'

function buildConversation(): SessionConversation {
  return {
    message_count: 2,
    empty_reason: null,
    summary: {
      has_conversation: true,
      message_count: 2,
      preview: 'Need help',
      activity_count: 0,
    },
    entries: [
      {
        sequence: 1,
        role: 'user',
        content: 'Need help with the CLI output',
        occurred_at: '2026-04-26T09:00:00Z',
        tool_calls: [],
        degraded: false,
        issues: [],
      },
      {
        sequence: 2,
        role: 'assistant',
        content: 'Here is the cleaned-up summary',
        occurred_at: '2026-04-26T09:01:00Z',
        tool_calls: [],
        degraded: true,
        issues: [
          {
            code: 'partial_message',
            severity: 'warning',
            message: 'message was incomplete',
            source_path: null,
            scope: 'event',
            event_sequence: 2,
          },
        ],
      },
    ],
  }
}

describe('ConversationTranscript', () => {
  it('marks user and assistant entries with role-specific visual state beyond the role badge', () => {
    render(<ConversationTranscript conversation={buildConversation()} stateScopeKey="session-1" />)

    expect(screen.getByTestId('conversation-entry-1')).toHaveAttribute('data-role', 'user')
    expect(screen.getByTestId('conversation-entry-1')).toHaveClass('border-emerald-300/35')
    expect(screen.getByTestId('conversation-entry-2')).toHaveAttribute('data-role', 'assistant')
    expect(screen.getByTestId('conversation-entry-2')).toHaveClass('border-cyan-300/35')
  })

  it('keeps degraded and issue indicators readable with assistant role styling', () => {
    render(<ConversationTranscript conversation={buildConversation()} stateScopeKey="session-1" />)

    const assistantEntry = screen.getByTestId('conversation-entry-2')

    expect(assistantEntry).toHaveAttribute('data-role', 'assistant')
    expect(assistantEntry).toHaveTextContent('partial')
    expect(assistantEntry).toHaveTextContent('message was incomplete')
  })

  it('hides and restores entry body, code, tool hints, and issue details while keeping metadata visible', async () => {
    const user = userEvent.setup()
    const conversation: SessionConversation = {
      ...buildConversation(),
      entries: [
        {
          sequence: 7,
          role: 'assistant',
          content: 'Visible body\n```sh\nnpm test\n```',
          occurred_at: '2026-04-26T09:01:00Z',
          tool_calls: [
            {
              name: 'skill-context',
              arguments_preview: 'long\ncontext',
              is_truncated: true,
              status: 'partial',
            },
          ],
          degraded: true,
          issues: [
            {
              code: 'partial_message',
              severity: 'warning',
              message: 'message was incomplete',
              source_path: null,
              scope: 'event',
              event_sequence: 7,
            },
          ],
        },
      ],
    }

    render(<ConversationTranscript conversation={conversation} stateScopeKey="session-1" />)

    const entry = screen.getByTestId('conversation-entry-7')

    expect(entry).toHaveTextContent('Visible body')
    expect(entry).toHaveTextContent('npm test')
    expect(entry).toHaveTextContent('skill-context')
    expect(entry).toHaveTextContent('message was incomplete')

    await user.click(screen.getByRole('button', { name: '発話 #7 を非表示' }))

    expect(entry).toHaveTextContent('発話 #7')
    expect(entry).toHaveTextContent('assistant')
    expect(entry).toHaveTextContent('2026-04-26 18:01:00 JST')
    expect(entry).toHaveTextContent('partial')
    expect(entry).not.toHaveTextContent('Visible body')
    expect(entry).not.toHaveTextContent('npm test')
    expect(entry).not.toHaveTextContent('skill-context')
    expect(entry).not.toHaveTextContent('message was incomplete')

    await user.click(screen.getByRole('button', { name: '発話 #7 を表示' }))

    expect(entry).toHaveTextContent('Visible body')
    expect(entry).toHaveTextContent('npm test')
    expect(entry).toHaveTextContent('skill-context')
    expect(entry).toHaveTextContent('message was incomplete')
  })

  it('resets entry visibility when the scope changes to a different session with the same payload', async () => {
    const user = userEvent.setup()
    const conversation = buildConversation()
    const { rerender } = render(
      <ConversationTranscript conversation={conversation} stateScopeKey="session-1" />,
    )

    await user.click(screen.getByRole('button', { name: '発話 #1 を非表示' }))

    expect(screen.queryByText('Need help with the CLI output')).not.toBeInTheDocument()

    rerender(
      <ConversationTranscript conversation={conversation} stateScopeKey="session-2" />,
    )

    expect(screen.getByText('Need help with the CLI output')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '発話 #1 を非表示' })).toBeInTheDocument()
  })
})
