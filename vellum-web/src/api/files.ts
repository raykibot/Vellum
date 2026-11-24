import type { UploadFileResponse } from '@/types/api';
import { apiClient } from './client';

export function uploadImage(file: File): Promise<UploadFileResponse> {
  const formData = new FormData();
  formData.append('file', file);
  return apiClient.post<UploadFileResponse>('/api/v1/files/upload', formData, {
    timeout: 60000,
  });
}
