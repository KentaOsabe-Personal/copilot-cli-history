import { describe, expect, it } from 'vitest'

import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'
import { formatTimelineContent } from './timelineContent.ts'

interface TimelineToolCallSummary {
  name: string | null
  arguments_preview: string | null
  is_truncated: boolean
  status: 'complete' | 'partial'
}

interface TimelineDetailSummary {
  category: string
  title: string
  body: string | null
}

type TimelineEventForContent = SessionTimelineEvent & {
  mapping_status: 'complete' | 'partial'
  tool_calls: readonly TimelineToolCallSummary[]
  detail: TimelineDetailSummary | null
}

function buildEvent(overrides: Partial<TimelineEventForContent> = {}): TimelineEventForContent {
  return {
    sequence: 1,
    kind: 'message',
    mapping_status: 'complete',
    raw_type: 'assistant_message',
    occurred_at: '2026-04-26T09:00:02Z',
    role: 'assistant',
    content: 'plain text',
    tool_calls: [],
    detail: null,
    raw_payload: {},
    degraded: false,
    issues: [],
    ...overrides,
  }
}

describe('formatTimelineContent', () => {
  it('extracts tool hints from canonical helper fields and preserves text/code order', () => {
    const event = buildEvent({
      content: 'Before code\n```ts\nconst answer = 42\n```\nAfter code',
      tool_calls: [
        {
          name: 'functions.bash',
          arguments_preview: '{"command":"pwd"}',
          is_truncated: false,
          status: 'complete',
        },
      ],
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
          name: 'functions.bash',
          argumentsPreview: '{"command":"pwd"}',
          isTruncated: false,
          status: 'complete',
        },
      ],
    })
  })

  it('keeps partial tool summaries even when only a subset of fields is available', () => {
    const event = buildEvent({
      content: null,
      tool_calls: [
        {
          name: null,
          arguments_preview: '{"input":"y"}',
          is_truncated: true,
          status: 'partial',
        },
      ],
    })

    expect(formatTimelineContent(event)).toEqual({
      blocks: [
        {
          kind: 'tool_hint',
          name: null,
          argumentsPreview: '{"input":"y"}',
          isTruncated: true,
          status: 'partial',
        },
      ],
    })
  })

  it('formats non-message detail summaries as dedicated blocks', () => {
    const event = buildEvent({
      kind: 'detail',
      role: null,
      content: null,
      detail: {
        category: 'tool_execution',
        title: 'tool.execution_start',
        body: 'functions.bash / tool-1',
      },
    })

    expect(formatTimelineContent(event)).toEqual({
      blocks: [
        {
          kind: 'detail',
          category: 'tool_execution',
          title: 'tool.execution_start',
          body: 'functions.bash / tool-1',
        },
      ],
    })
  })
})
