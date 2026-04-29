import { render, screen } from '@testing-library/react'
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
    render(<ConversationTranscript conversation={buildConversation()} />)

    expect(screen.getByTestId('conversation-entry-1')).toHaveAttribute('data-role', 'user')
    expect(screen.getByTestId('conversation-entry-1')).toHaveClass('border-emerald-300/35')
    expect(screen.getByTestId('conversation-entry-2')).toHaveAttribute('data-role', 'assistant')
    expect(screen.getByTestId('conversation-entry-2')).toHaveClass('border-cyan-300/35')
  })

  it('keeps degraded and issue indicators readable with assistant role styling', () => {
    render(<ConversationTranscript conversation={buildConversation()} />)

    const assistantEntry = screen.getByTestId('conversation-entry-2')

    expect(assistantEntry).toHaveAttribute('data-role', 'assistant')
    expect(assistantEntry).toHaveTextContent('partial')
    expect(assistantEntry).toHaveTextContent('message was incomplete')
  })
})
