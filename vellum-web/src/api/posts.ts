import type { CreatePostRequest, CursorPageResult, PostItem, PostType } from '@/types/api';
import { apiClient } from './client';

export type PostFilterType = 'ALL' | PostType;

export interface FetchPostsParams {
  size?: number;
  type?: PostFilterType;
  cursorTime?: string;
  cursorId?: string;
}

export function fetchPosts(params: FetchPostsParams): Promise<CursorPageResult<PostItem>> {
  return apiClient.get<CursorPageResult<PostItem>>('/api/v1/posts', {
    params,
  });
}

export function fetchPostDetail(id: string): Promise<PostItem> {
  return apiClient.get<PostItem>(`/api/v1/posts/${encodeURIComponent(id)}`);
}

export function createPost(payload: CreatePostRequest): Promise<PostItem> {
  return apiClient.post<PostItem>('/api/v1/posts', payload);
}

export function deletePost(id: string): Promise<null> {
  return apiClient.delete<null>(`/api/v1/posts/${encodeURIComponent(id)}`);
}
