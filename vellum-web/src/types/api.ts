export interface ApiResult<T> {
  code: number;
  message: string;
  data: T;
}

export interface CursorPageResult<T> {
  size: number;
  hasMore: boolean;
  nextCursorTime: string | null;
  nextCursorId: string | null;
  items: T[];
}

export type PostType = 'MOMENT' | 'ARTICLE';

export interface PostItem {
  id: string;
  type: PostType;
  title: string | null;
  content: string;
  locationCity: string | null;
  recordTime: string;
  createdAt: string;
  updatedAt: string;
  images: string[] | null;
  contentTruncated: boolean;
}

export interface CreatePostRequest {
  title?: string | null;
  type?: PostType;
  content?: string;
  locationCity?: string | null;
  recordTime?: string;
  imageIds?: string[];
}

export interface UploadFileResponse {
  id: string;
  url: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  expiresAt: string;
}
