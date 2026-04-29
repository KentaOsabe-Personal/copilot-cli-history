import { useEffect, useState } from 'react'

import { sessionApiClient } from '../api/sessionApi.ts'
import type {
  SessionApiClient,
  SessionApiError,
  SessionIndexMeta,
  SessionSummary,
} from '../api/sessionApi.types.ts'

export type SessionIndexState =
  | { status: 'loading' }
  | { status: 'empty' }
  | {
      status: 'success'
      sessions: readonly SessionSummary[]
      meta: SessionIndexMeta
    }
  | {
      status: 'error'
      error: SessionApiError
    }

export interface UseSessionIndexOptions {
  client?: SessionApiClient
}

export interface UseSessionIndexResult {
  state: SessionIndexState
}

type SettledSessionIndexState = Exclude<SessionIndexState, { status: 'loading' }>
type ReusableSessionIndexState = Extract<SessionIndexState, { status: 'success' | 'empty' }>

let lastReusableSnapshot: {
  client: SessionApiClient
  state: ReusableSessionIndexState
} | null = null

export function useSessionIndex(
  options: UseSessionIndexOptions = {},
): UseSessionIndexResult {
  const client = options.client ?? sessionApiClient
  const [settledState, setSettledState] = useState<{
    client: SessionApiClient
    state: SettledSessionIndexState
  } | null>(() => lastReusableSnapshot)

  useEffect(() => {
    const controller = new AbortController()
    let isActive = true

    void client.fetchSessionIndex(controller.signal).then((result) => {
      if (!isActive || controller.signal.aborted) {
        return
      }

      if (result.status === 'error') {
        setSettledState({
          client,
          state: {
            status: 'error',
            error: result.error,
          },
        })
        return
      }

      if (result.data.data.length === 0) {
        lastReusableSnapshot = {
          client,
          state: { status: 'empty' },
        }
        setSettledState({
          client,
          state: lastReusableSnapshot.state,
        })
        return
      }

      lastReusableSnapshot = {
        client,
        state: {
          status: 'success',
          sessions: result.data.data,
          meta: result.data.meta,
        },
      }
      setSettledState({
        client,
        state: lastReusableSnapshot.state,
      })
    })

    return () => {
      isActive = false
      controller.abort()
    }
  }, [client])

  if (settledState == null || settledState.client !== client) {
    return {
      state: { status: 'loading' },
    }
  }

  return { state: settledState.state }
}
