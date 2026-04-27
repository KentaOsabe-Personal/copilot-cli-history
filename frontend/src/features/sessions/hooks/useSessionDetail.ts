import { useEffect, useState } from 'react'

import { sessionApiClient } from '../api/sessionApi.ts'
import type {
  SessionApiClient,
  SessionApiError,
  SessionDetailResponse,
} from '../api/sessionApi.types.ts'

export type SessionDetailState =
  | { status: 'loading'; sessionId: string }
  | { status: 'not_found'; sessionId: string }
  | {
      status: 'success'
      sessionId: string
      detail: SessionDetailResponse['data']
    }
  | {
      status: 'error'
      sessionId: string
      error: SessionApiError
    }

export interface UseSessionDetailOptions {
  client?: SessionApiClient
}

export interface UseSessionDetailResult {
  state: SessionDetailState
}

type SettledSessionDetailState = Exclude<SessionDetailState, { status: 'loading' }>

export function useSessionDetail(
  sessionId: string,
  options: UseSessionDetailOptions = {},
): UseSessionDetailResult {
  const client = options.client ?? sessionApiClient
  const [settledState, setSettledState] = useState<{
    sessionId: string
    state: SettledSessionDetailState
  } | null>(null)

  useEffect(() => {
    const controller = new AbortController()
    let isActive = true

    void client.fetchSessionDetail(sessionId, controller.signal).then((result) => {
      if (!isActive || controller.signal.aborted) {
        return
      }

      if (result.status === 'success') {
        setSettledState({
          sessionId,
          state: {
            status: 'success',
            sessionId,
            detail: result.data.data,
          },
        })
        return
      }

      if (result.error.kind === 'not_found') {
        setSettledState({
          sessionId,
          state: {
            status: 'not_found',
            sessionId,
          },
        })
        return
      }

      setSettledState({
        sessionId,
        state: {
          status: 'error',
          sessionId,
          error: result.error,
        },
      })
    })

    return () => {
      isActive = false
      controller.abort()
    }
  }, [client, sessionId])

  if (settledState == null || settledState.sessionId !== sessionId) {
    return {
      state: {
        status: 'loading',
        sessionId,
      },
    }
  }

  return { state: settledState.state }
}
