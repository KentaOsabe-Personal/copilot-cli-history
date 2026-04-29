import type {
  SessionActivityEntry,
  SessionConversationEntry,
  SessionTimelineEvent,
} from '../api/sessionApi.types.ts'
import {
  extractContentBlocks,
  extractToolHintBlocks,
  type ConversationVisualBlock,
} from './conversationContent.ts'

export type TimelineVisualBlock =
  | ConversationVisualBlock
  | { kind: 'detail'; category: string; title: string; body: string | null }

export interface TimelineContentModel {
  blocks: readonly TimelineVisualBlock[]
}

export function formatTimelineContent(
  event: Pick<SessionTimelineEvent, 'content' | 'tool_calls' | 'detail'>,
): TimelineContentModel {
  return {
    blocks: [
      ...extractContentBlocks(event.content),
      ...extractToolHintBlocks(event.tool_calls),
      ...extractDetailBlocks(event.detail),
    ],
  }
}

function extractDetailBlocks(detail: SessionTimelineEvent['detail']): TimelineVisualBlock[] {
  if (detail == null) {
    return []
  }

  return [
    {
      kind: 'detail',
      category: detail.category,
      title: detail.title,
      body: detail.body,
    },
  ]
}

export interface ActivityContentModel {
  sequence: number
  category: string
  title: string
  summary: string | null
  rawType: string | null
  mappingStatus: 'complete' | 'partial'
  occurredAt: string | null
  sourcePath: string | null
  rawAvailable: boolean
  degraded: boolean
  issues: SessionActivityEntry['issues']
  blocks: readonly TimelineVisualBlock[]
}

export function formatActivityContent(entry: SessionActivityEntry): ActivityContentModel {
  return {
    sequence: entry.sequence,
    category: entry.category,
    title: entry.title,
    summary: entry.summary,
    rawType: entry.raw_type,
    mappingStatus: entry.mapping_status,
    occurredAt: entry.occurred_at,
    sourcePath: entry.source_path,
    rawAvailable: entry.raw_available,
    degraded: entry.degraded,
    issues: entry.issues,
    blocks: [
      {
        kind: 'detail',
        category: entry.category,
        title: entry.title,
        body: entry.summary,
      },
    ],
  }
}

export function deriveConversationEntriesFromTimeline(
  timeline: readonly SessionTimelineEvent[],
): SessionConversationEntry[] {
  return timeline
    .filter(isConversationTimelineEvent)
    .map((event) => ({
      sequence: event.sequence,
      role: event.role,
      content: event.content,
      occurred_at: event.occurred_at,
      tool_calls: event.tool_calls,
      degraded: event.degraded,
      issues: event.issues,
    }))
}

function isConversationTimelineEvent(
  event: SessionTimelineEvent,
): event is SessionTimelineEvent & { role: 'user' | 'assistant'; content: string } {
  return (
    event.kind === 'message' &&
    (event.role === 'user' || event.role === 'assistant') &&
    event.content != null &&
    event.content.length > 0
  )
}
