import type { SessionIssue, SessionSourceState, WorkContext } from '../api/sessionApi.types.ts'

const MISSING_TIMESTAMP_LABEL = '時刻不明'
const MISSING_WORK_CONTEXT_LABEL = '作業コンテキスト不明'
const MISSING_MODEL_LABEL = 'モデル不明'
const JST_TIME_ZONE = 'Asia/Tokyo'
const JST_SUFFIX = 'JST'

const ISSUE_SEVERITY_LABELS: Record<string, string> = {
  error: 'エラー',
  warning: '警告',
  info: '情報',
}

const ISSUE_SCOPE_LABELS: Record<string, string> = {
  session: 'セッション',
  event: 'イベント',
}

export function formatTimestamp(value: string | null): string {
  if (value == null) {
    return MISSING_TIMESTAMP_LABEL
  }

  const timestamp = new Date(value)

  if (Number.isNaN(timestamp.getTime())) {
    return value
  }

  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: JST_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
    hourCycle: 'h23',
  }).formatToParts(timestamp)

  const partValues = Object.fromEntries(parts.map((part) => [part.type, part.value]))

  return `${partValues.year}-${partValues.month}-${partValues.day} ${partValues.hour}:${partValues.minute}:${partValues.second} ${JST_SUFFIX}`
}

export function formatWorkContext(workContext: WorkContext): string {
  const repository = normalizeText(workContext.repository)
  const branch = normalizeText(workContext.branch)
  const cwd = normalizeText(workContext.cwd)
  const gitRoot = normalizeText(workContext.git_root)

  if (repository != null && branch != null) {
    return `${repository} @ ${branch}`
  }

  return repository ?? cwd ?? gitRoot ?? MISSING_WORK_CONTEXT_LABEL
}

export function formatModel(value: string | null): string {
  return normalizeText(value) ?? MISSING_MODEL_LABEL
}

export function formatDegradedLabel(degraded: boolean): string {
  return degraded ? '一部欠損あり' : '正常'
}

export function formatSourceStateLabel(sourceState: SessionSourceState): string {
  if (sourceState === 'workspace_only') {
    return 'workspace-only'
  }

  return sourceState
}

export function formatIssueMetadata(
  issue: Pick<SessionIssue, 'severity' | 'scope' | 'event_sequence'>,
): {
  severityLabel: string
  scopeLabel: string
  locationLabel: string | null
} {
  const scopeLabel = ISSUE_SCOPE_LABELS[issue.scope] ?? issue.scope

  return {
    severityLabel: ISSUE_SEVERITY_LABELS[issue.severity] ?? issue.severity,
    scopeLabel,
    locationLabel:
      issue.event_sequence != null
        ? `イベント #${issue.event_sequence}`
        : issue.scope === 'session'
          ? 'セッション全体'
          : scopeLabel,
  }
}

function normalizeText(value: string | null): string | null {
  const normalized = value?.trim()

  return normalized != null && normalized.length > 0 ? normalized : null
}
