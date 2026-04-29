import { describe, expect, it } from 'vitest'

import type { SessionConversationEntry } from '../api/sessionApi.types.ts'
import { formatConversationEntryContent } from './conversationContent.ts'

function buildEntry(overrides: Partial<SessionConversationEntry> = {}): SessionConversationEntry {
  return {
    sequence: 1,
    role: 'assistant',
    content: 'Before code\n```ts\nconst answer = 42\n```\nAfter code',
    occurred_at: '2026-04-26T09:00:02Z',
    tool_calls: [
      {
        name: 'functions.bash',
        arguments_preview: '{"command":"pwd"}',
        is_truncated: false,
        status: 'complete',
      },
    ],
    degraded: false,
    issues: [],
    ...overrides,
  }
}

describe('formatConversationEntryContent', () => {
  it('preserves text/code order and keeps tool hints as separate attached blocks', () => {
    expect(formatConversationEntryContent(buildEntry())).toEqual({
      role: 'assistant',
      sequence: 1,
      occurredAt: '2026-04-26T09:00:02Z',
      degraded: false,
      issues: [],
      blocks: [
        {
          kind: 'text',
          text: 'Before code\n',
        },
        {
          kind: 'code',
          language: 'ts',
          code: 'const answer = 42\n',
        },
        {
          kind: 'text',
          text: '\nAfter code',
        },
        {
          kind: 'tool_hint',
          name: 'functions.bash',
          argumentsPreview: '{"command":"pwd"}',
          isTruncated: false,
          status: 'complete',
        },
      ],
    })
  })

  it('keeps partial tool hints readable even when the assistant content is empty', () => {
    expect(
      formatConversationEntryContent(
        buildEntry({
          content: '',
          tool_calls: [
            {
              name: null,
              arguments_preview: null,
              is_truncated: true,
              status: 'partial',
            },
          ],
        }),
      ),
    ).toMatchObject({
      blocks: [
        {
          kind: 'tool_hint',
          name: null,
          argumentsPreview: null,
          isTruncated: true,
          status: 'partial',
        },
      ],
    })
  })
})
