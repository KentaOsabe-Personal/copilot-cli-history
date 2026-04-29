import type {
  SessionConversationEntry,
  SessionIssue,
  SessionTimelineToolCall,
} from '../api/sessionApi.types.ts'

export type ConversationVisualBlock =
  | { kind: 'text'; text: string }
  | { kind: 'code'; language: string | null; code: string }
  | {
      kind: 'tool_hint'
      name: string | null
      argumentsPreview: string | null
      isTruncated: boolean
      status: 'complete' | 'partial'
    }

export interface ConversationEntryContentModel {
  role: 'user' | 'assistant'
  sequence: number
  occurredAt: string | null
  degraded: boolean
  issues: readonly SessionIssue[]
  blocks: readonly ConversationVisualBlock[]
}

const CODE_FENCE_PATTERN = /```([^\n`]*)\n?([\s\S]*?)```/g

export function formatConversationEntryContent(
  entry: SessionConversationEntry,
): ConversationEntryContentModel {
  return {
    role: entry.role,
    sequence: entry.sequence,
    occurredAt: entry.occurred_at,
    degraded: entry.degraded,
    issues: entry.issues,
    blocks: [
      ...extractContentBlocks(entry.content),
      ...extractToolHintBlocks(entry.tool_calls),
    ],
  }
}

export function extractContentBlocks(content: string | null): ConversationVisualBlock[] {
  if (content == null || content.length === 0) {
    return []
  }

  const blocks: ConversationVisualBlock[] = []
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

export function extractToolHintBlocks(
  toolCalls: readonly SessionTimelineToolCall[] | undefined,
): ConversationVisualBlock[] {
  return (toolCalls ?? []).map((toolCall) => ({
    kind: 'tool_hint',
    name: toolCall.name,
    argumentsPreview: toolCall.arguments_preview,
    isTruncated: toolCall.is_truncated,
    status: toolCall.status,
  }))
}

function pushTextBlock(blocks: ConversationVisualBlock[], text: string) {
  if (text.length === 0) {
    return
  }

  blocks.push({
    kind: 'text',
    text,
  })
}

function normalizeLanguage(value: string): string | null {
  const language = value.trim()

  return language.length > 0 ? language : null
}
