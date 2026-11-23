import {
  useInfiniteQuery,
  useMutation,
  useQueryClient,
  type InfiniteData,
} from '@tanstack/react-query';
import { createPost, deletePost, fetchPosts } from '@/api/posts';
import type { CreatePostRequest, PageResult, PostItem } from '@/types/api';

export const POSTS_QUERY_KEY = ['posts'] as const;
const PAGE_SIZE = 20;

export function usePostsTimeline() {
  return useInfiniteQuery({
    queryKey: POSTS_QUERY_KEY,
    queryFn: ({ pageParam }) => fetchPosts(pageParam, PAGE_SIZE),
    initialPageParam: 1,
    getNextPageParam: (lastPage) =>
      lastPage.page * lastPage.size < lastPage.total ? lastPage.page + 1 : undefined,
  });
}

export function flattenPosts(data?: InfiniteData<PageResult<PostItem>>): PostItem[] {
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

export function useCreatePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: CreatePostRequest) => createPost(payload),
    onSuccess: (created) => {
      queryClient.setQueryData<InfiniteData<PageResult<PostItem>>>(POSTS_QUERY_KEY, (old) => {
        if (!old || old.pages.length === 0) return old;
        const firstPage = old.pages[0];
        const restPages = old.pages.slice(1);
        const mergedFirstItems = [created, ...firstPage.items.filter((i) => i.id !== created.id)].sort(
          comparePostsDesc,
        );
        return {
          ...old,
          pages: [
            {
              ...firstPage,
              total: firstPage.total + 1,
              items: mergedFirstItems,
            },
            ...restPages,
          ],
        };
      });
      void queryClient.invalidateQueries({ queryKey: POSTS_QUERY_KEY });
    },
  });
}

export function useDeletePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => deletePost(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: POSTS_QUERY_KEY });
      const previous = queryClient.getQueryData<InfiniteData<PageResult<PostItem>>>(POSTS_QUERY_KEY);
      queryClient.setQueryData<InfiniteData<PageResult<PostItem>>>(POSTS_QUERY_KEY, (old) => {
        if (!old) return old;
        return {
          ...old,
          pages: old.pages.map((page) => ({
            ...page,
            total: Math.max(0, page.total - 1),
            items: page.items.filter((item) => item.id !== id),
          })),
        };
      });
      return { previous };
    },
    onError: (_err, _id, context) => {
      if (context?.previous) {
        queryClient.setQueryData(POSTS_QUERY_KEY, context.previous);
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: POSTS_QUERY_KEY });
    },
  });
}
