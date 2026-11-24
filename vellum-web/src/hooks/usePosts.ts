import {
  useInfiniteQuery,
  useMutation,
  useQuery,
  useQueryClient,
  type InfiniteData,
  type QueryKey,
} from '@tanstack/react-query';
import { createPost, deletePost, fetchPostDetail, fetchPosts, type PostFilterType } from '@/api/posts';
import type { CreatePostRequest, CursorPageResult, PostItem } from '@/types/api';

export type PostFilter = 'all' | 'moment' | 'article';

export const POSTS_QUERY_KEY = ['posts'] as const;
const ROW_ESTIMATE_PX = 78;
const BUFFER_ROWS = 2;

export interface PostCursor {
  cursorTime: string;
  cursorId: string;
}

export function computeInitialPageSize(): number {
  if (typeof window === 'undefined') {
    return 11;
  }
  const availableHeight = Math.max(window.innerHeight - 140, 400);
  return Math.min(20, Math.max(10, Math.ceil(availableHeight / ROW_ESTIMATE_PX) + BUFFER_ROWS));
}

function toApiFilterType(filter: PostFilter): PostFilterType | undefined {
  if (filter === 'moment') return 'MOMENT';
  if (filter === 'article') return 'ARTICLE';
  return undefined;
}

export function usePostsTimeline(filter: PostFilter, pageSize: number) {
  const apiType = toApiFilterType(filter);
  return useInfiniteQuery({
    queryKey: [...POSTS_QUERY_KEY, filter, pageSize] as const,
    queryFn: ({ pageParam }) =>
      fetchPosts({
        size: pageSize,
        type: apiType,
        cursorTime: pageParam?.cursorTime,
        cursorId: pageParam?.cursorId,
      }),
    initialPageParam: null as PostCursor | null,
    getNextPageParam: (lastPage) =>
      lastPage.hasMore && lastPage.nextCursorTime && lastPage.nextCursorId
        ? {
            cursorTime: lastPage.nextCursorTime,
            cursorId: lastPage.nextCursorId,
          }
        : undefined,
    staleTime: 5 * 60_000,
    gcTime: 30 * 60_000,
  });
}

export function usePostDetail(post: PostItem | null) {
  const needsDetail = Boolean(post && post.contentTruncated);
  return useQuery({
    queryKey: ['post', post?.id ?? ''] as const,
    queryFn: () => fetchPostDetail(post!.id),
    enabled: needsDetail,
    initialData: post && !post.contentTruncated ? post : undefined,
    staleTime: 10 * 60_000,
    gcTime: 30 * 60_000,
  });
}

export function flattenPosts(data?: InfiniteData<CursorPageResult<PostItem>>): PostItem[] {
  if (!data) return [];
  const seen = new Set<string>();
  const list: PostItem[] = [];
  for (const page of data.pages) {
    for (const item of page.items) {
      if (!seen.has(item.id)) {
        seen.add(item.id);
        list.push(item);
      }
    }
  }
  return list;
}

function comparePostsDesc(a: PostItem, b: PostItem): number {
  const timeDiff = Date.parse(b.recordTime) - Date.parse(a.recordTime);
  if (timeDiff !== 0) return timeDiff;
  return b.id.localeCompare(a.id);
}

function shouldIncludeInFilter(filter: unknown, postType: PostItem['type']): boolean {
  if (filter === 'all') return true;
  if (filter === 'moment') return postType === 'MOMENT';
  if (filter === 'article') return postType === 'ARTICLE';
  return false;
}

export function useCreatePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: CreatePostRequest) => createPost(payload),
    onSuccess: (created) => {
      queryClient.setQueryData(['post', created.id], created);

      const cachedLists = queryClient.getQueriesData<InfiniteData<CursorPageResult<PostItem>>>({
        queryKey: POSTS_QUERY_KEY,
      });

      for (const [queryKey, old] of cachedLists) {
        const filter = Array.isArray(queryKey) ? queryKey[1] : undefined;
        if (!shouldIncludeInFilter(filter, created.type)) {
          continue;
        }
        if (!old || old.pages.length === 0) {
          continue;
        }
        const firstPage = old.pages[0];
        const restPages = old.pages.slice(1);
        const mergedFirstItems = [created, ...firstPage.items.filter((i) => i.id !== created.id)].sort(
          comparePostsDesc,
        );
        queryClient.setQueryData<InfiniteData<CursorPageResult<PostItem>>>(queryKey, {
          ...old,
          pages: [
            {
              ...firstPage,
              items: mergedFirstItems,
            },
            ...restPages,
          ],
        });
      }
    },
  });
}

export function useDeletePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => deletePost(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: POSTS_QUERY_KEY });
      const previousLists = queryClient.getQueriesData<InfiniteData<CursorPageResult<PostItem>>>({
        queryKey: POSTS_QUERY_KEY,
      });

      for (const [queryKey, old] of previousLists) {
        if (!old) continue;
        queryClient.setQueryData<InfiniteData<CursorPageResult<PostItem>>>(queryKey, {
          ...old,
          pages: old.pages.map((page) => ({
            ...page,
            items: page.items.filter((item) => item.id !== id),
          })),
        });
      }

      queryClient.removeQueries({ queryKey: ['post', id] });
      return { previousLists } as {
        previousLists: Array<[QueryKey, InfiniteData<CursorPageResult<PostItem>> | undefined]>;
      };
    },
    onError: (_err, _id, context) => {
      if (!context?.previousLists) return;
      for (const [queryKey, snapshot] of context.previousLists) {
        queryClient.setQueryData(queryKey, snapshot);
      }
    },
  });
}
