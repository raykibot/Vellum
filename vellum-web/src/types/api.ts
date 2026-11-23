export interface ApiResult<T> {
  code: number;
  message: string;
  data: T;
}

export interface PageResult<T> {
  page: number;
  size: number;
  total: number;
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
}

export interface CreatePostRequest {
  title?: string | null;
  type?: PostType;
  content: string;
  locationCity?: string | null;
  recordTime?: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  expiresAt: string;
}
