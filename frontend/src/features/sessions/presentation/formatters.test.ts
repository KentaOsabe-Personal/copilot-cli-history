import { describe, expect, it } from 'vitest'

import {
  formatDegradedLabel,
  formatIssueMetadata,
  formatModel,
  formatTimestamp,
  formatWorkContext,
} from './formatters.ts'

describe('formatters', () => {
  it('formats missing timestamps with a stable placeholder', () => {
    expect(formatTimestamp(null)).toBe('時刻不明')
  })

  it('formats ISO timestamps into a stable UTC label', () => {
    expect(formatTimestamp('2026-04-26T09:05:00Z')).toBe('2026-04-26 09:05:00 UTC')
  })

  it('formats missing work context and missing model with placeholders', () => {
    expect(
      formatWorkContext({
        cwd: null,
        git_root: null,
        repository: null,
        branch: null,
      }),
    ).toBe('作業コンテキスト不明')
    expect(formatModel(null)).toBe('モデル不明')
  })

  it('formats degraded and issue metadata into readable labels', () => {
    expect(formatDegradedLabel(true)).toBe('一部欠損あり')
    expect(formatDegradedLabel(false)).toBe('正常')
    expect(
      formatIssueMetadata({
        severity: 'warning',
        scope: 'event',
        event_sequence: 8,
      }),
    ).toEqual({
      severityLabel: '警告',
      scopeLabel: 'イベント',
      locationLabel: 'イベント #8',
    })
  })
})
