import { describe, expect, it } from 'vitest'

import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import { formatTimelineContent } from './timelineContent.ts'

function buildEvent(overrides: Partial<SessionTimelineEvent> = {}): SessionTimelineEvent {
  return {
    sequence: 1,
    kind: 'message',
    raw_type: 'assistant_message',
    occurred_at: '2026-04-26T09:00:02Z',
    role: 'assistant',
    content: 'plain text',
    raw_payload: {},
    degraded: false,
    issues: [],
    ...overrides,
  }
}

describe('formatTimelineContent', () => {
  it('extracts tool hints and fenced code while preserving text/code order', () => {
    const event = buildEvent({
      content: 'Before code\n```ts\nconst answer = 42\n```\nAfter code',
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
    })

    expect(formatTimelineContent(event)).toEqual({
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
          name: 'bash',
          argumentsPreview: '{"command":"pwd"}',
        },
      ],
    })
  })

  it('falls back to plain text when the payload does not match a recognized tool hint schema', () => {
    const event = buildEvent({
      content: 'Unknown tool payload should stay readable',
      raw_payload: {
        toolRequests: [
          {
            label: 'bash',
          },
        ],
      },
    })

    expect(formatTimelineContent(event)).toEqual({
      blocks: [
        {
          kind: 'text',
          text: 'Unknown tool payload should stay readable',
        },
      ],
    })
  })

  it('still exposes a tool hint when content is empty', () => {
    const event = buildEvent({
      content: null,
      raw_payload: {
        toolRequests: [
          {
            name: 'write_bash',
            arguments: '{"input":"y"}',
          },
        ],
      },
    })

    expect(formatTimelineContent(event)).toEqual({
      blocks: [
        {
          kind: 'tool_hint',
          name: 'write_bash',
          argumentsPreview: '{"input":"y"}',
        },
      ],
    })
  })
})
