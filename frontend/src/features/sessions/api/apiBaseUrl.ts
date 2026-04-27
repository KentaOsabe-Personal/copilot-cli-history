import type {
  SessionApiEnvironment,
  SessionApiError,
} from './sessionApi.types.ts'

const API_BASE_URL_ENV = 'VITE_API_BASE_URL'
const defaultEnvironment: SessionApiEnvironment = {
  VITE_API_BASE_URL: import.meta.env.VITE_API_BASE_URL,
}

export type ApiBaseUrlResult =
  | { status: 'success'; baseUrl: URL }
  | { status: 'error'; error: Extract<SessionApiError, { kind: 'config' }> }

export function resolveApiBaseUrl(
  env: SessionApiEnvironment = defaultEnvironment,
): ApiBaseUrlResult {
  const value = env.VITE_API_BASE_URL?.trim()

  if (value == null || value.length === 0) {
    return {
      status: 'error',
      error: {
        kind: 'config',
        code: 'api_base_url_missing',
        message: 'VITE_API_BASE_URL is not configured',
        details: {
          env: API_BASE_URL_ENV,
        },
      },
    }
  }

  try {
    return {
      status: 'success',
      baseUrl: new URL(value),
    }
  } catch {
    return {
      status: 'error',
      error: {
        kind: 'config',
        code: 'api_base_url_invalid',
        message: 'VITE_API_BASE_URL must be an absolute URL',
        details: {
          env: API_BASE_URL_ENV,
          value,
        },
      },
    }
  }
}
