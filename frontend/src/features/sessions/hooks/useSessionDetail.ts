import { useCallback, useEffect, useRef, useState } from 'react'

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
      rawStatus: 'idle' | 'loading' | 'included' | 'error'
      rawError?: SessionApiError
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
  requestRaw: () => void
}

type SettledSessionDetailState = Exclude<SessionDetailState, { status: 'loading' }>

export function useSessionDetail(
  sessionId: string,
  options: UseSessionDetailOptions = {},
): UseSessionDetailResult {
  const client = options.client ?? sessionApiClient
  const rawAbortControllerRef = useRef<AbortController | null>(null)
  const [settledState, setSettledState] = useState<{
    client: SessionApiClient
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
          client,
          sessionId,
          state: {
            status: 'success',
            sessionId,
            detail: result.data.data,
            rawStatus: result.data.data.raw_included ? 'included' : 'idle',
          },
        })
        return
      }

      if (result.error.kind === 'not_found') {
        setSettledState({
          client,
          sessionId,
          state: {
            status: 'not_found',
            sessionId,
          },
        })
        return
      }

      setSettledState({
        client,
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
      rawAbortControllerRef.current?.abort()
      rawAbortControllerRef.current = null
    }
  }, [client, sessionId])

  const requestRaw = useCallback(() => {
    if (
      settledState == null ||
      settledState.client !== client ||
      settledState.sessionId !== sessionId ||
      settledState.state.status !== 'success' ||
      settledState.state.rawStatus === 'loading' ||
      settledState.state.rawStatus === 'included'
    ) {
      return
    }

    rawAbortControllerRef.current?.abort()
    const controller = new AbortController()
    rawAbortControllerRef.current = controller

    setSettledState({
      ...settledState,
      state: {
        ...settledState.state,
        rawStatus: 'loading',
        rawError: undefined,
      },
    })

    void client.fetchSessionDetailWithRaw(sessionId, controller.signal).then((result) => {
      if (controller.signal.aborted) {
        return
      }

      setSettledState((latest) => {
        if (
          latest == null ||
          latest.client !== client ||
          latest.sessionId !== sessionId ||
          latest.state.status !== 'success'
        ) {
          return latest
        }

        if (result.status === 'success') {
          return {
            ...latest,
            state: {
              status: 'success',
              sessionId,
              detail: result.data.data,
              rawStatus: result.data.data.raw_included ? 'included' : 'idle',
            },
          }
        }

        return {
          ...latest,
          state: {
            ...latest.state,
            rawStatus: 'error',
            rawError: result.error,
          },
        }
      })
    })
  }, [client, sessionId, settledState])

  if (settledState == null || settledState.client !== client || settledState.sessionId !== sessionId) {
    return {
      state: {
        status: 'loading',
        sessionId,
      },
      requestRaw,
    }
  }

  return { state: settledState.state, requestRaw }
}
