import { describe, expect, it } from 'vitest'

import {
  buildSessionMetadataItems,
  formatDegradedLabel,
  formatIssueMetadata,
  formatTimestamp,
  getDisplayableModel,
  getDisplayableWorkContext,
} from './formatters.ts'

describe('formatters', () => {
  it('formats missing timestamps with a stable placeholder', () => {
    expect(formatTimestamp(null)).toBe('時刻不明')
  })

  it('formats ISO timestamps into a stable JST label', () => {
    expect(formatTimestamp('2026-04-26T09:05:00Z')).toBe('2026-04-26 18:05:00 JST')
  })

  it('formats JST midnight with a zero-based hour', () => {
    expect(formatTimestamp('2026-04-26T15:05:00Z')).toBe('2026-04-27 00:05:00 JST')
  })

  it('keeps invalid timestamps out of the JST success format', () => {
    expect(formatTimestamp('not-a-timestamp')).toBe('not-a-timestamp')
    expect(formatTimestamp('not-a-timestamp')).not.toContain('JST')
  })

  it('returns displayable work context and model values only when real metadata exists', () => {
    expect(
      getDisplayableWorkContext({
        cwd: null,
        git_root: null,
        repository: null,
        branch: null,
      }),
    ).toBeNull()
    expect(getDisplayableModel(null)).toBeNull()
    expect(
      getDisplayableWorkContext({
        cwd: '/workspace/example',
        git_root: '/workspace/example',
        repository: 'octo/example',
        branch: 'main',
      }),
    ).toBe('octo/example @ main')
    expect(getDisplayableModel('  gpt-5.4  ')).toBe('gpt-5.4')
  })

  it('builds metadata items without placeholder-only work context or model entries', () => {
    expect(
      buildSessionMetadataItems({
        updatedAt: null,
        workContext: {
          cwd: null,
          git_root: null,
          repository: null,
          branch: null,
        },
        selectedModel: null,
      }),
    ).toEqual([
      {
        label: '更新日時',
        value: '時刻不明',
      },
    ])
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
