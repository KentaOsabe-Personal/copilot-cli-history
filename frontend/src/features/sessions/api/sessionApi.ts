import { resolveApiBaseUrl } from './apiBaseUrl.ts'
import type {
  ErrorEnvelope,
  SessionApiClient,
  SessionApiEnvironment,
  SessionApiError,
  SessionApiResult,
} from './sessionApi.types.ts'

type FetchImpl = typeof fetch

interface CreateSessionApiClientOptions {
  fetchImpl?: FetchImpl
  env?: SessionApiEnvironment
}

export function createSessionApiClient(
  options: CreateSessionApiClientOptions = {},
): SessionApiClient {
  const fetchImpl = options.fetchImpl ?? fetch
  const env = options.env

  return {
    fetchSessionIndex(signal) {
      return requestJson('/api/sessions', { fetchImpl, env, signal })
    },
    fetchSessionDetail(sessionId, signal) {
      if (sessionId.length === 0) {
        throw new Error('sessionId must not be empty')
      }

      return requestJson(`/api/sessions/${encodeURIComponent(sessionId)}`, {
        fetchImpl,
        env,
        signal,
      })
    },
  }
}

export const sessionApiClient = createSessionApiClient()

async function requestJson<T>(
  path: string,
  options: {
    fetchImpl: FetchImpl
    env?: SessionApiEnvironment
    signal?: AbortSignal
  },
): Promise<SessionApiResult<T>> {
  const baseUrlResult = resolveApiBaseUrl(options.env)

  if (baseUrlResult.status === 'error') {
    return {
      status: 'error',
      error: baseUrlResult.error,
    }
  }

  try {
    const response = await options.fetchImpl(new URL(path, baseUrlResult.baseUrl), {
      headers: {
        Accept: 'application/json',
      },
      signal: options.signal,
    })

    if (response.ok) {
      return {
        status: 'success',
        data: (await response.json()) as T,
      }
    }

    const errorEnvelope = await parseErrorEnvelope(response)

    return {
      status: 'error',
      error: normalizeHttpError(response.status, errorEnvelope),
    }
  } catch (error) {
    return {
      status: 'error',
      error: {
        kind: 'network',
        code: 'network_error',
        message: 'Network request failed',
        details: {
          cause: error instanceof Error ? error.message : String(error),
        },
      },
    }
  }
}

function normalizeHttpError(status: number, errorEnvelope: ErrorEnvelope): SessionApiError {
  const { code, message, details } = errorEnvelope.error

  if (status === 404 && code === 'session_not_found') {
    return {
      kind: 'not_found',
      httpStatus: 404,
      code,
      message,
      details,
    }
  }

  return {
    kind: 'backend',
    httpStatus: status,
    code,
    message,
    details,
  }
}

async function parseErrorEnvelope(response: Response): Promise<ErrorEnvelope> {
  const payload = (await response.json()) as unknown

  if (isErrorEnvelope(payload)) {
    return payload
  }

  return {
    error: {
      code: 'unexpected_error',
      message: `Request failed with status ${response.status}`,
      details: {
        status: response.status,
      },
    },
  }
}

function isErrorEnvelope(value: unknown): value is ErrorEnvelope {
  if (typeof value !== 'object' || value == null) {
    return false
  }

  const error = (value as { error?: unknown }).error

  if (typeof error !== 'object' || error == null) {
    return false
  }

  const candidate = error as {
    code?: unknown
    message?: unknown
    details?: unknown
  }

  return (
    typeof candidate.code === 'string' &&
    typeof candidate.message === 'string' &&
    typeof candidate.details === 'object' &&
    candidate.details != null
  )
}
