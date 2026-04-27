import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { SessionSummary } from '../api/sessionApi.types.ts'
import { useSessionIndex } from '../hooks/useSessionIndex.ts'
import SessionIndexPage from './SessionIndexPage.tsx'

vi.mock('../hooks/useSessionIndex.ts', () => ({
  useSessionIndex: vi.fn(),
}))

const mockedUseSessionIndex = vi.mocked(useSessionIndex)

function buildSessionSummary(overrides: Partial<SessionSummary> = {}): SessionSummary {
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
    event_count: 5,
    message_snapshot_count: 3,
    degraded: false,
    issues: [],
    ...overrides,
  }
}

describe('SessionIndexPage', () => {
  beforeEach(() => {
    mockedUseSessionIndex.mockReset()
  })

  it('renders a loading panel while the session index is being fetched', () => {
    mockedUseSessionIndex.mockReturnValue({
      state: { status: 'loading' },
    })

    render(
      <MemoryRouter>
        <SessionIndexPage />
      </MemoryRouter>,
    )

    expect(screen.getByRole('heading', { name: 'セッション一覧' })).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'セッション一覧を読み込んでいます' })).toBeInTheDocument()
  })

  it('renders an empty panel when the backend returns no sessions', () => {
    mockedUseSessionIndex.mockReturnValue({
      state: { status: 'empty' },
    })

    render(
      <MemoryRouter>
        <SessionIndexPage />
      </MemoryRouter>,
    )

    expect(screen.getByText('表示できるセッションはありません。')).toBeInTheDocument()
  })

  it('renders ordered session cards with degraded state and placeholder metadata', () => {
    mockedUseSessionIndex.mockReturnValue({
      state: {
        status: 'success',
        sessions: [
          buildSessionSummary({
            id: 'session-b',
            updated_at: '2026-04-26T10:05:00Z',
            degraded: true,
          }),
          buildSessionSummary({
            id: 'session-a',
            updated_at: null,
            work_context: {
              cwd: null,
              git_root: null,
              repository: null,
              branch: null,
            },
            selected_model: null,
          }),
        ],
        meta: {
          count: 2,
          partial_results: true,
        },
      },
    })

    render(
      <MemoryRouter>
        <SessionIndexPage />
      </MemoryRouter>,
    )

    expect(screen.getAllByRole('heading', { level: 3 }).map((node) => node.textContent)).toEqual([
      'session-b',
      'session-a',
    ])
    expect(screen.getAllByText('一部欠損あり')).toHaveLength(1)
    expect(screen.getByText('時刻不明')).toBeInTheDocument()
    expect(screen.getByText('作業コンテキスト不明')).toBeInTheDocument()
    expect(screen.getByText('モデル不明')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'session-b を開く' })).toHaveAttribute(
      'href',
      '/sessions/session-b',
    )
  })

  it('renders an error panel without success cards when the fetch fails', () => {
    mockedUseSessionIndex.mockReturnValue({
      state: {
        status: 'error',
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

    render(
      <MemoryRouter>
        <SessionIndexPage />
      </MemoryRouter>,
    )

    expect(screen.getByRole('heading', { name: 'セッション一覧を表示できません' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'session-123 を開く' })).not.toBeInTheDocument()
  })

  it('navigates to the detail route when a session card is selected', async () => {
    const user = userEvent.setup()

    mockedUseSessionIndex.mockReturnValue({
      state: {
        status: 'success',
        sessions: [
          buildSessionSummary({
            id: 'session-123',
          }),
        ],
        meta: {
          count: 1,
          partial_results: false,
        },
      },
    })

    render(
      <MemoryRouter initialEntries={['/']}>
        <Routes>
          <Route path="/" element={<SessionIndexPage />} />
          <Route path="/sessions/:sessionId" element={<p>detail route</p>} />
        </Routes>
      </MemoryRouter>,
    )

    await user.click(screen.getByRole('link', { name: 'session-123 を開く' }))

    expect(screen.getByText('detail route')).toBeInTheDocument()
  })
})
