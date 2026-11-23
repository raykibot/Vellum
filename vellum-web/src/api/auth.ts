import type { LoginRequest, LoginResponse } from '@/types/api';
import { apiClient } from './client';

export function loginRequest(payload: LoginRequest): Promise<LoginResponse> {
  return apiClient.post<LoginResponse>('/api/v1/auth/login', payload);
}
