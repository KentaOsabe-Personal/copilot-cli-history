import { useCallback, useEffect, useRef, useState } from 'react'

import { sessionApiClient } from '../api/sessionApi.ts'
import type {
  HistorySyncResponse,
  SessionApiClient,
  SessionApiError,
} from '../api/sessionApi.types.ts'
import type { SessionIndexSettledState } from './useSessionIndex.ts'

export type HistorySyncState =
  | { status: 'idle' }
  | { status: 'syncing' }
  | { status: 'synced_with_sessions'; result: HistorySyncResponse['data'] }
  | { status: 'synced_empty'; result: HistorySyncResponse['data'] }
  | {
      status: 'refresh_error'
      result: HistorySyncResponse['data']
      error: SessionApiError
    }
  | { status: 'conflict'; error: SessionApiError }
  | { status: 'sync_error'; error: SessionApiError }

export interface UseHistorySyncOptions {
  client?: SessionApiClient
  reloadSessions: () => Promise<SessionIndexSettledState>
}

export interface UseHistorySyncResult {
  state: HistorySyncState
  isSyncing: boolean
  startSync(): Promise<void>
}

export function useHistorySync(options: UseHistorySyncOptions): UseHistorySyncResult {
  const client = options.client ?? sessionApiClient
  const { reloadSessions } = options
  const [state, setState] = useState<HistorySyncState>({ status: 'idle' })
  const activeSyncRef = useRef<Promise<void> | null>(null)
  const isMountedRef = useRef(true)

  useEffect(() => {
    isMountedRef.current = true

    return () => {
      isMountedRef.current = false
    }
  }, [])

  const startSync = useCallback((): Promise<void> => {
    if (activeSyncRef.current != null) {
      return activeSyncRef.current
    }

    if (isMountedRef.current) {
      setState({ status: 'syncing' })
    }

    const syncPromise = (async () => {
      const syncResult = await client.syncHistory()

      if (!isMountedRef.current) {
        return
      }

      if (syncResult.status === 'error') {
        setState(
          isHistorySyncConflict(syncResult.error)
            ? { status: 'conflict', error: syncResult.error }
            : { status: 'sync_error', error: syncResult.error },
        )

        return
      }

      const syncData = syncResult.data.data
      const reloadResult = await reloadSessions()

      if (!isMountedRef.current) {
        return
      }

      if (reloadResult.status === 'success') {
        setState({ status: 'synced_with_sessions', result: syncData })

        return
      }

      if (reloadResult.status === 'empty') {
        setState({ status: 'synced_empty', result: syncData })

        return
      }

      setState({
        status: 'refresh_error',
        result: syncData,
        error: reloadResult.error,
      })
    })()

    activeSyncRef.current = syncPromise.finally(() => {
      activeSyncRef.current = null
    })

    return activeSyncRef.current
  }, [client, reloadSessions])

  return {
    state,
    isSyncing: state.status === 'syncing',
    startSync,
  }
}

function isHistorySyncConflict(error: SessionApiError): boolean {
  return (
    error.kind === 'backend' &&
    error.httpStatus === 409 &&
    error.code === 'history_sync_running'
  )
}
