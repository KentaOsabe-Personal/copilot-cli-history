import { describe, expect, it, vi } from 'vitest'

import { createSessionApiClient } from './sessionApi'

function jsonResponse(body: unknown, init?: ResponseInit) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    ...init,
  })
}

describe('createSessionApiClient', () => {
  it('returns success for the session index response without changing backend order', async () => {
    const payload = {
      data: [
        {
          id: 'session-b',
          source_format: 'current',
          created_at: '2026-04-26T10:00:00Z',
          updated_at: '2026-04-26T10:05:00Z',
          work_context: {
            cwd: '/workspace/session-b',
            git_root: '/workspace/session-b',
            repository: 'octo/example',
            branch: 'feature/b',
          },
          selected_model: 'gpt-5.4',
          event_count: 3,
          message_snapshot_count: 1,
          degraded: false,
          issues: [],
        },
        {
          id: 'session-a',
          source_format: 'legacy',
          created_at: '2026-04-26T08:00:00Z',
          updated_at: null,
          work_context: {
            cwd: null,
            git_root: null,
            repository: null,
            branch: null,
          },
          selected_model: null,
          event_count: 1,
          message_snapshot_count: 0,
          degraded: true,
          issues: [
            {
              code: 'legacy.partial',
              severity: 'warning',
              message: 'legacy payload was incomplete',
              source_path: '/tmp/history-session-state/legacy.json',
              scope: 'session',
              event_sequence: null,
            },
          ],
        },
      ],
      meta: {
        count: 2,
        partial_results: true,
      },
    }
    const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(jsonResponse(payload))
    const client = createSessionApiClient({
      fetchImpl: fetchMock,
      env: { VITE_API_BASE_URL: 'http://localhost:30000' },
    })

    await expect(client.fetchSessionIndex()).resolves.toEqual({
      status: 'success',
      data: payload,
    })
    expect(String(fetchMock.mock.calls[0][0])).toBe('http://localhost:30000/api/sessions')
  })

  it('normalizes a detail 404 session_not_found into a not_found error', async () => {
    const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(
      jsonResponse(
        {
          error: {
            code: 'session_not_found',
            message: 'session was not found',
            details: {
              session_id: 'missing-session',
            },
          },
        },
        { status: 404 },
      ),
    )
    const client = createSessionApiClient({
      fetchImpl: fetchMock,
      env: { VITE_API_BASE_URL: 'http://localhost:30000' },
    })

    await expect(client.fetchSessionDetail('missing-session')).resolves.toEqual({
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
    })
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      'http://localhost:30000/api/sessions/missing-session',
    )
  })

  it('normalizes backend failures into a backend error', async () => {
    const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(
      jsonResponse(
        {
          error: {
            code: 'root_missing',
            message: 'history root does not exist',
            details: {
              path: '/tmp/.copilot',
            },
          },
        },
        { status: 503 },
      ),
    )
    const client = createSessionApiClient({
      fetchImpl: fetchMock,
      env: { VITE_API_BASE_URL: 'http://localhost:30000' },
    })

    await expect(client.fetchSessionIndex()).resolves.toEqual({
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
    })
  })

  it('returns a config error before requesting when the API base URL is missing', async () => {
    const fetchMock = vi.fn<typeof fetch>()
    const client = createSessionApiClient({
      fetchImpl: fetchMock,
      env: {},
    })

    await expect(client.fetchSessionIndex()).resolves.toEqual({
      status: 'error',
      error: {
        kind: 'config',
        code: 'api_base_url_missing',
        message: 'VITE_API_BASE_URL is not configured',
        details: {
          env: 'VITE_API_BASE_URL',
        },
      },
    })
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('returns a config error before requesting when the API base URL is malformed', async () => {
    const fetchMock = vi.fn<typeof fetch>()
    const client = createSessionApiClient({
      fetchImpl: fetchMock,
      env: { VITE_API_BASE_URL: '/relative-only' },
    })

    await expect(client.fetchSessionIndex()).resolves.toEqual({
      status: 'error',
      error: {
        kind: 'config',
        code: 'api_base_url_invalid',
        message: 'VITE_API_BASE_URL must be an absolute URL',
        details: {
          env: 'VITE_API_BASE_URL',
          value: '/relative-only',
        },
      },
    })
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('normalizes network failures into a network error', async () => {
    const fetchMock = vi.fn<typeof fetch>().mockRejectedValue(new TypeError('Failed to fetch'))
    const client = createSessionApiClient({
      fetchImpl: fetchMock,
      env: { VITE_API_BASE_URL: 'http://localhost:30000' },
    })

    await expect(client.fetchSessionIndex()).resolves.toEqual({
      status: 'error',
      error: {
        kind: 'network',
        code: 'network_error',
        message: 'Network request failed',
        details: {
          cause: 'Failed to fetch',
        },
      },
    })
  })
})
