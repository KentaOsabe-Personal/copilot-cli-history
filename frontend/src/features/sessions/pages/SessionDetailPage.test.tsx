import { render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { SessionDetail } from '../api/sessionApi.types.ts'
import { useSessionDetail } from '../hooks/useSessionDetail.ts'
import SessionDetailPage from './SessionDetailPage.tsx'

vi.mock('../hooks/useSessionDetail.ts', () => ({
  useSessionDetail: vi.fn(),
}))

const mockedUseSessionDetail = vi.mocked(useSessionDetail)

function buildDetail(overrides: Partial<SessionDetail> = {}): SessionDetail {
  return {
    id: 'session-123',
    source_format: 'current',
    created_at: '2026-04-26T09:00:00Z',
    updated_at: '2026-04-26T09:05:00Z',
    work_context: {
      cwd: '/workspace/session-123',
      git_root: '/workspace/session-123',
      repository: 'octo/example',
      branch: 'main',
    },
    selected_model: 'gpt-5.4',
    degraded: true,
    issues: [
      {
        code: 'session.partial',
        severity: 'warning',
        message: 'session timeline is incomplete',
        source_path: '/tmp/session.json',
        scope: 'session',
        event_sequence: null,
      },
    ],
    message_snapshots: [],
    timeline: [
      {
        sequence: 1,
        kind: 'message',
        raw_type: 'assistant_message',
        occurred_at: '2026-04-26T09:00:02Z',
        role: 'assistant',
        content: '説明です\n```ts\nconst answer = 42\n```',
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
        degraded: false,
        issues: [],
      },
      {
        sequence: 2,
        kind: 'partial',
        raw_type: 'assistant_partial',
        occurred_at: null,
        role: 'assistant',
        content: 'partial payload remains readable',
        raw_payload: {},
        degraded: true,
        issues: [
          {
            code: 'event.partial',
            severity: 'warning',
            message: 'event payload is partial',
            source_path: null,
            scope: 'event',
            event_sequence: 2,
          },
        ],
      },
    ],
    ...overrides,
  }
}

function renderDetailPage(initialEntry = '/sessions/session-123') {
  return render(
    <MemoryRouter initialEntries={[initialEntry]}>
      <Routes>
        <Route path="/sessions/:sessionId" element={<SessionDetailPage />} />
      </Routes>
    </MemoryRouter>,
  )
}

describe('SessionDetailPage', () => {
  beforeEach(() => {
    mockedUseSessionDetail.mockReset()
  })

  it('renders a loading panel while the detail is being fetched', () => {
    mockedUseSessionDetail.mockReturnValue({
      state: {
        status: 'loading',
        sessionId: 'session-123',
      },
    })

    renderDetailPage()

    expect(screen.getByRole('heading', { name: 'セッション詳細' })).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'セッション詳細を読み込んでいます' })).toBeInTheDocument()
  })

  it('renders header metadata, session issues, and timeline entries for a degraded success response', () => {
    mockedUseSessionDetail.mockReturnValue({
      state: {
        status: 'success',
        sessionId: 'session-123',
        detail: buildDetail(),
      },
    })

    renderDetailPage()

    expect(screen.getAllByText('session-123').length).toBeGreaterThan(0)
    expect(screen.getByRole('link', { name: 'セッション一覧へ戻る' })).toHaveAttribute('href', '/')
    expect(screen.getAllByText('一部欠損あり').length).toBeGreaterThan(0)
    expect(screen.getByText('session timeline is incomplete')).toBeInTheDocument()
    expect(screen.getAllByText('警告').length).toBeGreaterThan(0)
    expect(screen.getByText('セッション全体')).toBeInTheDocument()
    expect(screen.getByText('message')).toBeInTheDocument()
    expect(screen.getAllByText('assistant').length).toBeGreaterThan(0)
    expect(screen.getByText('イベント #1')).toBeInTheDocument()
    expect(screen.getByText('説明です')).toBeInTheDocument()
    expect(screen.getByText('const answer = 42')).toBeInTheDocument()
    expect(screen.getByText('bash')).toBeInTheDocument()
    expect(screen.getByText('partial payload remains readable')).toBeInTheDocument()
    expect(screen.getByText('event payload is partial')).toBeInTheDocument()
  })

  it('renders a dedicated not found panel with a link back to the index', () => {
    mockedUseSessionDetail.mockReturnValue({
      state: {
        status: 'not_found',
        sessionId: 'missing-session',
      },
    })

    renderDetailPage('/sessions/missing-session')

    expect(screen.getByRole('heading', { name: 'セッションが見つかりません' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'セッション一覧へ戻る' })).toHaveAttribute('href', '/')
  })

  it('renders an error panel with a link back to the index', () => {
    mockedUseSessionDetail.mockReturnValue({
      state: {
        status: 'error',
        sessionId: 'session-123',
        error: {
          kind: 'backend',
          httpStatus: 503,
          code: 'root_missing',
          message: 'history root does not exist',
          details: {
            path: '/tmp/.copilot',
          },
        },
      },
    })

    renderDetailPage()

    expect(screen.getByRole('heading', { name: 'セッション詳細を表示できません' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'セッション一覧へ戻る' })).toHaveAttribute('href', '/')
  })
})
