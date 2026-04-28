import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'

export type TimelineVisualBlock =
  | { kind: 'text'; text: string }
  | { kind: 'code'; language: string | null; code: string }
  | {
      kind: 'tool_hint'
      name: string | null
      argumentsPreview: string | null
      isTruncated: boolean
      status: 'complete' | 'partial'
    }
  | { kind: 'detail'; category: string; title: string; body: string | null }

export interface TimelineContentModel {
  blocks: readonly TimelineVisualBlock[]
}

const CODE_FENCE_PATTERN = /```([^\n`]*)\n?([\s\S]*?)```/g

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

function extractContentBlocks(content: string | null): TimelineVisualBlock[] {
  if (content == null || content.length === 0) {
    return []
  }

  const blocks: TimelineVisualBlock[] = []
  let lastIndex = 0

  for (const match of content.matchAll(CODE_FENCE_PATTERN)) {
    const [fullMatch, languageHint, code] = match
    const matchIndex = match.index ?? 0

    pushTextBlock(blocks, content.slice(lastIndex, matchIndex))
    blocks.push({
      kind: 'code',
      language: normalizeLanguage(languageHint),
      code,
    })
    lastIndex = matchIndex + fullMatch.length
  }

  pushTextBlock(blocks, content.slice(lastIndex))

  return blocks
}

function pushTextBlock(blocks: TimelineVisualBlock[], text: string) {
  if (text.length === 0) {
    return
  }

  blocks.push({
    kind: 'text',
    text,
  })
}

function extractToolHintBlocks(
  toolCalls: SessionTimelineEvent['tool_calls'] | undefined,
): TimelineVisualBlock[] {
  return (toolCalls ?? []).map((toolCall) => ({
    kind: 'tool_hint',
    name: toolCall.name,
    argumentsPreview: toolCall.arguments_preview,
    isTruncated: toolCall.is_truncated,
    status: toolCall.status,
  }))
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

function normalizeLanguage(value: string): string | null {
  const language = value.trim()

  return language.length > 0 ? language : null
}
