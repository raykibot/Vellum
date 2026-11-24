import { useEffect, useMemo, useRef, useState } from 'react';
import { cn } from '@/lib/utils';
import {
  computeInitialPageSize,
  flattenPosts,
  useDeletePost,
  usePostDetail,
  usePostsTimeline,
  type PostFilter,
} from '@/hooks/usePosts';
import { ArticleEditor, type ArticleEditorHandle } from '@/components/article/ArticleEditor';
import { ArticleReader } from '@/components/article/ArticleReader';
import { QuickComposeModal } from '@/components/compose/QuickComposeModal';
import { TopNav } from '@/components/layout/TopNav';
import { SettingsModal } from '@/components/settings/SettingsModal';
import { MomentDetail } from '@/components/timeline/MomentDetail';
import { TimelineRail } from '@/components/timeline/TimelineRail';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

interface ImportedDraft {
  title?: string;
  content?: string;
}

export function TimelinePage() {
  const [filter, setFilter] = useState<PostFilter>('all');
  const [pageSize] = useState(() => computeInitialPageSize());
  const { data, isLoading, hasNextPage, isFetchingNextPage, fetchNextPage } = usePostsTimeline(
    filter,
    pageSize,
  );
  const deleteMutation = useDeletePost();

  const posts = useMemo(() => flattenPosts(data), [data]);

  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [mobileShowDetail, setMobileShowDetail] = useState(false);

  const [composeOpen, setComposeOpen] = useState(false);
  const [composingArticle, setComposingArticle] = useState(false);
  const [composeSession, setComposeSession] = useState(0);
  const [sidebarBeforeCompose, setSidebarBeforeCompose] = useState(true);
  const [articleSubmitting, setArticleSubmitting] = useState(false);
  const [importedDraft, setImportedDraft] = useState<ImportedDraft | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);

  const editorRef = useRef<ArticleEditorHandle>(null);

  useEffect(() => {
    if (posts.length === 0) {
      setSelectedId(null);
      return;
    }
    const exists = posts.some((p) => p.id === selectedId);
    if (!exists) {
      setSelectedId(posts[0].id);
    }
  }, [posts, selectedId]);

  useEffect(() => {
    const handleShortcut = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key === '\\') {
        event.preventDefault();
        setSidebarOpen((v) => !v);
      }
    };
    window.addEventListener('keydown', handleShortcut);
    return () => window.removeEventListener('keydown', handleShortcut);
  }, []);

  const activePost = useMemo(
    () => posts.find((p) => p.id === selectedId) ?? null,
    [posts, selectedId],
  );

  const articleDetailQuery = usePostDetail(
    !composingArticle && activePost?.type === 'ARTICLE' ? activePost : null,
  );

  const handleSelectPost = (item: PostItem) => {
    setComposingArticle(false);
    setImportedDraft(null);
    setSelectedId(item.id);
    setMobileShowDetail(true);
  };

  const startArticleCompose = (draft?: ImportedDraft) => {
    if (!composingArticle) {
      setSidebarBeforeCompose(sidebarOpen);
    }
    setSidebarOpen(false);
    setImportedDraft(draft ?? null);
    setComposeSession((v) => v + 1);
    setComposingArticle(true);
    setMobileShowDetail(true);
  };

  const cancelArticleCompose = () => {
    setComposingArticle(false);
    setImportedDraft(null);
    setSidebarOpen(sidebarBeforeCompose);
    if (posts.length === 0) {
      setMobileShowDetail(false);
    }
  };

  const handleArticlePublished = (created: PostItem) => {
    if (filter === 'moment') {
      setFilter('all');
    }
    setComposingArticle(false);
    setImportedDraft(null);
    setSelectedId(created.id);
    setSidebarOpen(sidebarBeforeCompose);
    setMobileShowDetail(true);
  };

  const handleMomentCreated = (created: PostItem) => {
    if (filter === 'article') {
      setFilter('all');
    }
    setComposingArticle(false);
    setImportedDraft(null);
    setSelectedId(created.id);
    setMobileShowDetail(true);
  };

  const handleDeletePost = async (id: string) => {
    const idx = posts.findIndex((p) => p.id === id);
    const nextPost = posts[idx + 1] ?? posts[idx - 1] ?? null;
    await deleteMutation.mutateAsync(id);
    setSelectedId(nextPost?.id ?? null);
    if (!nextPost) {
      setMobileShowDetail(false);
    }
  };

  const handleBrandClick = () => {
    if (composingArticle) {
      setComposingArticle(false);
      setImportedDraft(null);
    }
    setFilter('all');
    setSidebarOpen(true);
    setMobileShowDetail(false);
  };

  return (
    <div
      className="h-screen w-full flex flex-col overflow-hidden"
      style={{ backgroundColor: 'var(--v-canvas)', color: 'var(--v-ink)' }}
    >
      <TopNav
        sidebarOpen={sidebarOpen}
        onToggleSidebar={() => setSidebarOpen((v) => !v)}
        composingArticle={composingArticle}
        articleSubmitting={articleSubmitting}
        onWriteMoment={() => setComposeOpen(true)}
        onWriteArticle={() => startArticleCompose()}
        onCancelArticle={cancelArticleCompose}
        onPublishArticle={() => void editorRef.current?.submit()}
        onBrandClick={handleBrandClick}
        onOpenSettings={() => setSettingsOpen(true)}
      />

      <main className="flex-1 flex min-h-0">
        <TimelineRail
          posts={posts}
          selectedId={composingArticle ? null : selectedId}
          onSelect={handleSelectPost}
          filter={filter}
          onFilterChange={setFilter}
          sidebarOpen={sidebarOpen}
          onImportArticleFile={(parsed) => startArticleCompose(parsed)}
          hasNextPage={Boolean(hasNextPage)}
          isFetchingNextPage={isFetchingNextPage}
          onLoadMore={() => void fetchNextPage()}
          isLoading={isLoading}
          className={cn(mobileShowDetail ? 'hidden md:flex' : 'flex')}
        />

        <section
          className={cn(
            'subtle-scroll flex-1 overflow-y-auto transition-colors duration-200',
            mobileShowDetail ? 'block' : 'hidden md:block',
          )}
          style={{ backgroundColor: 'var(--v-canvas)' }}
        >
          {composingArticle ? (
            <ArticleEditor
              key={composeSession}
              ref={editorRef}
              initialTitle={importedDraft?.title}
              initialContent={importedDraft?.content}
              onSubmittingChange={setArticleSubmitting}
              onPublished={handleArticlePublished}
            />
          ) : activePost?.type === 'ARTICLE' ? (
            <ArticleReader
              post={articleDetailQuery.data ?? activePost}
              isLoadingBody={Boolean(activePost.contentTruncated && !articleDetailQuery.data)}
              isDeleting={deleteMutation.isPending}
              onDelete={handleDeletePost}
              sidebarOpen={sidebarOpen}
              onToggleFocus={() => setSidebarOpen((v) => !v)}
              onMobileBack={() => setMobileShowDetail(false)}
            />
          ) : activePost ? (
            <MomentDetail
              post={activePost}
              isDeleting={deleteMutation.isPending}
              onDelete={handleDeletePost}
              onMobileBack={() => setMobileShowDetail(false)}
            />
          ) : !isLoading ? (
            <div className="h-full flex items-center justify-center p-8">
              {filter === 'article' ? (
                <TactileButton variant="solid" onClick={() => startArticleCompose()}>
                  写长文
                </TactileButton>
              ) : (
                <TactileButton variant="solid" onClick={() => setComposeOpen(true)}>
                  写一条
                </TactileButton>
              )}
            </div>
          ) : null}
        </section>
      </main>

      <QuickComposeModal
        open={composeOpen}
        onClose={() => setComposeOpen(false)}
        onCreated={handleMomentCreated}
      />

      <SettingsModal open={settingsOpen} onClose={() => setSettingsOpen(false)} />
    </div>
  );
}
