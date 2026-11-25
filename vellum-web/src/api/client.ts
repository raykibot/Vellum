import axios, { AxiosError, type AxiosRequestConfig } from 'axios';
import { clearAuthSession, getApiBaseUrl, getToken } from '@/lib/storage';
import type { ApiResult } from '@/types/api';

export class ApiError extends Error {
  code: number;

  constructor(code: number, message: string) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
  }
}

type UnauthorizedListener = () => void;
const unauthorizedListeners = new Set<UnauthorizedListener>();

export function onUnauthorized(listener: UnauthorizedListener): () => void {
  unauthorizedListeners.add(listener);
  return () => {
    unauthorizedListeners.delete(listener);
  };
}

function notifyUnauthorized(): void {
  clearAuthSession();
  unauthorizedListeners.forEach((listener) => listener());
}

const http = axios.create({
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

http.interceptors.request.use((config) => {
  const baseUrl = getApiBaseUrl();
  config.baseURL = baseUrl || undefined;

  if (config.data instanceof FormData && config.headers) {
    if (typeof config.headers.delete === 'function') {
      config.headers.delete('Content-Type');
    } else {
      delete config.headers['Content-Type'];
    }
  }

  const token = getToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

function unwrapResult<T>(payload: ApiResult<T>): T {
  if (payload && typeof payload.code === 'number') {
    if (payload.code === 0) {
      return payload.data;
    }
    if (payload.code === 401) {
      notifyUnauthorized();
    }
    throw new ApiError(payload.code, payload.message || '请求失败');
  }
  throw new ApiError(500, '响应格式异常');
}

function extractFilename(disposition?: string): string | null {
  if (!disposition) return null;
  const utf8Match = disposition.match(/filename\*=UTF-8''([^;]+)/i);
  if (utf8Match?.[1]) {
    try {
      return decodeURIComponent(utf8Match[1].trim().replace(/^["']|["']$/g, ''));
    } catch {
      // ignore invalid URI encoding and fall back to plain filename
    }
  }
  const plainMatch = disposition.match(/filename="?([^";]+)"?/i);
  return plainMatch?.[1]?.trim() || null;
}

async function tryParseJsonBlob(blob: Blob): Promise<ApiResult<unknown> | null> {
  try {
    const text = await blob.text();
    const parsed = JSON.parse(text) as ApiResult<unknown>;
    if (parsed && typeof parsed.code === 'number') {
      return parsed;
    }
  } catch {
    // non-JSON blob payload
  }
  return null;
}

function handleRequestError(error: unknown): never {
  if (error instanceof ApiError) {
    throw error;
  }
  if (axios.isAxiosError(error)) {
    const axiosErr = error as AxiosError<ApiResult<unknown>>;
    const status = axiosErr.response?.status;
    const serverPayload = axiosErr.response?.data;

    if (status === 401 || serverPayload?.code === 401) {
      notifyUnauthorized();
      throw new ApiError(401, serverPayload?.message || '登录已过期');
    }
    if (serverPayload && typeof serverPayload.message === 'string') {
      throw new ApiError(serverPayload.code || status || 500, serverPayload.message);
    }
    if (status) {
      throw new ApiError(status, `请求失败 (${status})`);
    }
    throw new ApiError(0, '无法连接服务器');
  }
  throw new ApiError(500, '未知错误');
}

export const apiClient = {
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response = await http.get<ApiResult<T>>(url, config);
      return unwrapResult(response.data);
    } catch (error) {
      return handleRequestError(error);
    }
  },

  async getBlob(
    url: string,
    config?: AxiosRequestConfig,
  ): Promise<{ blob: Blob; filename: string | null }> {
    try {
      const response = await http.get<Blob>(url, {
        ...config,
        responseType: 'blob',
      });
      const contentType = String(
        response.headers?.['content-type'] || response.data.type || '',
      ).toLowerCase();
      if (contentType.includes('application/json')) {
        const jsonPayload = await tryParseJsonBlob(response.data);
        if (jsonPayload) {
          unwrapResult(jsonPayload);
        }
        throw new ApiError(500, '响应格式异常');
      }
      const disposition = response.headers?.['content-disposition'];
      const filename = extractFilename(typeof disposition === 'string' ? disposition : undefined);
      return { blob: response.data, filename };
    } catch (error) {
      if (axios.isAxiosError(error) && error.response?.data instanceof Blob) {
        const jsonPayload = await tryParseJsonBlob(error.response.data);
        if (jsonPayload) {
          if (error.response.status === 401 || jsonPayload.code === 401) {
            notifyUnauthorized();
            throw new ApiError(401, jsonPayload.message || '登录已过期');
          }
          throw new ApiError(
            jsonPayload.code || error.response.status || 500,
            jsonPayload.message || '请求失败',
          );
        }
      }
      return handleRequestError(error);
    }
  },

  async post<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response = await http.post<ApiResult<T>>(url, data, config);
      return unwrapResult(response.data);
    } catch (error) {
      return handleRequestError(error);
    }
  },

  async delete<T = null>(url: string, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response = await http.delete<ApiResult<T>>(url, config);
      return unwrapResult(response.data);
    } catch (error) {
      return handleRequestError(error);
    }
  },
};
