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
