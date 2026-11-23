import type { CreatePostRequest, PageResult, PostItem } from '@/types/api';
import { apiClient } from './client';

export function fetchPosts(page: number, size = 20): Promise<PageResult<PostItem>> {
  return apiClient.get<PageResult<PostItem>>('/api/v1/posts', {
    params: { page, size },
  });
}

export function createPost(payload: CreatePostRequest): Promise<PostItem> {
  return apiClient.post<PostItem>('/api/v1/posts', payload);
}

export function deletePost(id: string): Promise<null> {
  return apiClient.delete<null>(`/api/v1/posts/${encodeURIComponent(id)}`);
}
