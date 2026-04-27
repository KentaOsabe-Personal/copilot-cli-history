import type { SessionTimelineEvent } from '../api/sessionApi.types.ts'

export type TimelineVisualBlock =
  | { kind: 'text'; text: string }
  | { kind: 'code'; language: string | null; code: string }
  | { kind: 'tool_hint'; name: string; argumentsPreview: string | null }

export interface TimelineContentModel {
  blocks: readonly TimelineVisualBlock[]
}

const CODE_FENCE_PATTERN = /```([^\n`]*)\n?([\s\S]*?)```/g

export function formatTimelineContent(
  event: Pick<SessionTimelineEvent, 'content' | 'raw_payload'>,
): TimelineContentModel {
  return {
    blocks: [
      ...extractContentBlocks(event.content),
      ...extractToolHintBlocks(event.raw_payload),
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

function extractToolHintBlocks(rawPayload: unknown): TimelineVisualBlock[] {
  const payload = asRecord(rawPayload)
  const toolRequests = payload?.toolRequests

  if (!Array.isArray(toolRequests)) {
    return []
  }

  return toolRequests.flatMap((toolRequest) => {
    const request = asRecord(toolRequest)
    const name = readString(request?.toolName) ?? readString(request?.name)

    if (name == null) {
      return []
    }

    return [
      {
        kind: 'tool_hint' as const,
        name,
        argumentsPreview: formatArgumentsPreview(
          request?.arguments ?? request?.input ?? request?.parameters ?? null,
        ),
      },
    ]
  })
}

function formatArgumentsPreview(value: unknown): string | null {
  if (value == null) {
    return null
  }

  if (typeof value === 'string') {
    return value
  }

  if (
    typeof value === 'number' ||
    typeof value === 'boolean' ||
    Array.isArray(value) ||
    typeof value === 'object'
  ) {
    return JSON.stringify(value)
  }

  return String(value)
}

function normalizeLanguage(value: string): string | null {
  const language = value.trim()

  return language.length > 0 ? language : null
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value != null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null
}

function readString(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null
}
