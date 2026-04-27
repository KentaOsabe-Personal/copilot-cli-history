import { render, screen, waitFor } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import type {
  SessionApiClient,
  SessionApiResult,
  SessionDetailResponse,
  SessionIndexResponse,
} from '../api/sessionApi.types.ts'
import { useSessionDetail } from './useSessionDetail.ts'

function deferred<T>() {
  let resolve!: (value: T) => void

  const promise = new Promise<T>((nextResolve) => {
    resolve = nextResolve
  })

  return { promise, resolve }
}

function createClient(fetchSessionDetail: SessionApiClient['fetchSessionDetail']): SessionApiClient {
  return {
    fetchSessionIndex: vi.fn<
      SessionApiClient['fetchSessionIndex']
    >(async (): Promise<SessionApiResult<SessionIndexResponse>> => {
      throw new Error('fetchSessionIndex should not be called in useSessionDetail tests')
    }),
    fetchSessionDetail,
  }
}

function buildDetail(sessionId: string): SessionDetailResponse {
  return {
    data: {
      id: sessionId,
      source_format: 'current',
      created_at: '2026-04-26T09:00:00Z',
      updated_at: '2026-04-26T09:05:00Z',
      work_context: {
        cwd: `/workspace/${sessionId}`,
        git_root: `/workspace/${sessionId}`,
        repository: 'octo/example',
        branch: 'main',
      },
      selected_model: 'gpt-5.4',
      degraded: false,
      issues: [],
      message_snapshots: [],
      timeline: [],
    },
  }
}

function StateProbe({
  client,
  sessionId,
}: {
  client: SessionApiClient
  sessionId: string
}) {
  const { state } = useSessionDetail(sessionId, { client })

  return <pre data-testid="state">{JSON.stringify(state)}</pre>
}

function readState() {
  return JSON.parse(screen.getByTestId('state').textContent ?? 'null')
}

describe('useSessionDetail', () => {
  it('starts in loading and transitions to success for the active session id', async () => {
    const request = deferred<SessionApiResult<SessionDetailResponse>>()
    const fetchSessionDetail = vi.fn<SessionApiClient['fetchSessionDetail']>(() => request.promise)
    const client = createClient(fetchSessionDetail)

    render(<StateProbe client={client} sessionId="session-123" />)

    expect(readState()).toEqual({
      status: 'loading',
      sessionId: 'session-123',
    })

    request.resolve({
      status: 'success',
      data: buildDetail('session-123'),
    })

    await waitFor(() =>
      expect(readState()).toEqual({
        status: 'success',
        sessionId: 'session-123',
        detail: buildDetail('session-123').data,
      }),
    )
  })

  it('maps session_not_found to a dedicated not_found state', async () => {
    const fetchSessionDetail = vi.fn<SessionApiClient['fetchSessionDetail']>(async () => ({
      status: 'error',
      error: {
        kind: 'not_found',
        httpStatus: 404,
        code: 'session_not_found',
        message: 'session was not found',
        details: {
          session_id: 'missing-session',
        },
      },
    }))
    const client = createClient(fetchSessionDetail)

    render(<StateProbe client={client} sessionId="missing-session" />)

    await waitFor(() =>
      expect(readState()).toEqual({
        status: 'not_found',
        sessionId: 'missing-session',
      }),
    )
  })

  it('maps backend, network, and config failures to an error state', async () => {
    const fetchSessionDetail = vi.fn<SessionApiClient['fetchSessionDetail']>(async () => ({
      status: 'error',
      error: {
        kind: 'network',
        code: 'network_error',
        message: 'Network request failed',
        details: {
          cause: 'Failed to fetch',
        },
      },
    }))
    const client = createClient(fetchSessionDetail)

    render(<StateProbe client={client} sessionId="session-500" />)

    await waitFor(() =>
      expect(readState()).toEqual({
        status: 'error',
        sessionId: 'session-500',
        error: {
          kind: 'network',
          code: 'network_error',
          message: 'Network request failed',
          details: {
            cause: 'Failed to fetch',
          },
        },
      }),
    )
  })

  it('aborts the previous request and ignores its late response when the route param changes', async () => {
    const sessionARequest = deferred<SessionApiResult<SessionDetailResponse>>()
    const sessionBRequest = deferred<SessionApiResult<SessionDetailResponse>>()
    const observedSignals: AbortSignal[] = []
    const fetchSessionDetail = vi.fn<SessionApiClient['fetchSessionDetail']>((sessionId, signal) => {
      if (signal != null) {
        observedSignals.push(signal)
      }

      if (sessionId === 'session-a') {
        return sessionARequest.promise
      }

      return sessionBRequest.promise
    })
    const client = createClient(fetchSessionDetail)

    const { rerender } = render(<StateProbe client={client} sessionId="session-a" />)

    expect(readState()).toEqual({
      status: 'loading',
      sessionId: 'session-a',
    })

    rerender(<StateProbe client={client} sessionId="session-b" />)

    expect(observedSignals[0]?.aborted).toBe(true)
    expect(readState()).toEqual({
      status: 'loading',
      sessionId: 'session-b',
    })

    sessionARequest.resolve({
      status: 'success',
      data: buildDetail('session-a'),
    })

    await Promise.resolve()

    expect(readState()).toEqual({
      status: 'loading',
      sessionId: 'session-b',
    })

    sessionBRequest.resolve({
      status: 'success',
      data: buildDetail('session-b'),
    })

    await waitFor(() =>
      expect(readState()).toEqual({
        status: 'success',
        sessionId: 'session-b',
        detail: buildDetail('session-b').data,
      }),
    )
  })

  it('returns to loading when the client changes for the same session id', async () => {
    const clientARequest = deferred<SessionApiResult<SessionDetailResponse>>()
    const clientBRequest = deferred<SessionApiResult<SessionDetailResponse>>()
    const clientA = createClient(vi.fn<SessionApiClient['fetchSessionDetail']>(() => clientARequest.promise))
    const clientB = createClient(vi.fn<SessionApiClient['fetchSessionDetail']>(() => clientBRequest.promise))

    const { rerender } = render(<StateProbe client={clientA} sessionId="session-123" />)

    clientARequest.resolve({
      status: 'success',
      data: buildDetail('session-123'),
    })

    await waitFor(() =>
      expect(readState()).toEqual({
        status: 'success',
        sessionId: 'session-123',
        detail: buildDetail('session-123').data,
      }),
    )

    rerender(<StateProbe client={clientB} sessionId="session-123" />)

    expect(readState()).toEqual({
      status: 'loading',
      sessionId: 'session-123',
    })

    clientBRequest.resolve({
      status: 'error',
      error: {
        kind: 'backend',
        httpStatus: 503,
        code: 'service_unavailable',
        message: 'service unavailable',
        details: {},
      },
    })

    await waitFor(() =>
      expect(readState()).toEqual({
        status: 'error',
        sessionId: 'session-123',
        error: {
          kind: 'backend',
          httpStatus: 503,
          code: 'service_unavailable',
          message: 'service unavailable',
          details: {},
        },
      }),
    )
  })
})
