import { useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { flattenPosts, useDeletePost, usePostsTimeline } from '@/hooks/usePosts';
import { ArticleDrawer } from '@/components/article/ArticleDrawer';
import { ArticleEditor, type ArticleEditorHandle } from '@/components/article/ArticleEditor';
import { ArticleReader } from '@/components/article/ArticleReader';
import { TopNav } from '@/components/layout/TopNav';
import { SettingsModal } from '@/components/settings/SettingsModal';
import { TactileButton } from '@/components/ui/TactileButton';

interface ImportedArticleLocationState {
  importedTitle?: string;
  importedContent?: string;
}

export function ArticlePage() {
  const { id } = useParams<{ id: string }>();
  const location = useLocation();
  const navigate = useNavigate();

  const { data, isLoading } = usePostsTimeline();
  const deleteMutation = useDeletePost();

  const posts = useMemo(() => flattenPosts(data), [data]);
  const articles = useMemo(() => posts.filter((p) => p.type === 'ARTICLE'), [posts]);

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [editorSubmitting, setEditorSubmitting] = useState(false);
  const editorRef = useRef<ArticleEditorHandle>(null);

  const isExplicitNew = location.pathname === '/articles/new';
  const activeArticle = useMemo(() => {
    if (isExplicitNew) return null;
    if (id) {
      return articles.find((a) => a.id === id) ?? posts.find((p) => p.id === id) ?? null;
    }
    return articles[0] ?? null;
  }, [isExplicitNew, id, articles, posts]);

  const showEditor = isExplicitNew || (!id && !isLoading && articles.length === 0);
  const locState = (location.state as ImportedArticleLocationState | null) ?? null;

  useEffect(() => {
    const handleShortcut = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key === '\\') {
        event.preventDefault();
        setDrawerOpen((v) => !v);
      }
    };
    window.addEventListener('keydown', handleShortcut);
    return () => window.removeEventListener('keydown', handleShortcut);
  }, []);

  const handleDeleteArticle = async (articleId: string) => {
    const nextArticle = articles.find((a) => a.id !== articleId);
    await deleteMutation.mutateAsync(articleId);
    if (nextArticle) {
      navigate(`/articles/${nextArticle.id}`, { replace: true });
    } else {
      navigate('/articles/new', { replace: true });
    }
  };

  return (
    <div
      className="h-screen w-full flex flex-col overflow-hidden"
      style={{ backgroundColor: 'var(--v-canvas)', color: 'var(--v-ink)' }}
    >
      <TopNav
        activeTab="article"
        showSidebarToggle
        sidebarOpen={drawerOpen}
        onToggleSidebar={() => setDrawerOpen((v) => !v)}
        primaryActionLabel={showEditor ? '发布' : '写长文'}
        primaryActionLoading={showEditor && editorSubmitting}
        onPrimaryAction={() => {
          if (showEditor) {
            void editorRef.current?.submit();
          } else {
            navigate('/articles/new');
          }
        }}
        onOpenSettings={() => setSettingsOpen(true)}
      />

      <ArticleDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        articles={articles}
        activeId={activeArticle?.id}
      />

      <main
        className="flex-1 overflow-y-auto subtle-scroll transition-colors duration-200"
        style={{ backgroundColor: 'var(--v-canvas)' }}
      >
        {showEditor ? (
          <ArticleEditor
            ref={editorRef}
            initialTitle={locState?.importedTitle}
            initialContent={locState?.importedContent}
            onSubmittingChange={setEditorSubmitting}
            onPublished={(created) => navigate(`/articles/${created.id}`, { replace: true })}
          />
        ) : activeArticle ? (
          <ArticleReader
            post={activeArticle}
            isDeleting={deleteMutation.isPending}
            onDelete={handleDeleteArticle}
          />
        ) : isLoading ? (
          <div className="max-w-[660px] mx-auto px-6 md:px-10 py-14 space-y-5">
            <div className="h-8 w-56 rounded-lg animate-pulse" style={{ backgroundColor: 'var(--v-hover)' }} />
            <div className="h-4 w-full rounded animate-pulse" style={{ backgroundColor: 'var(--v-hover)' }} />
            <div className="h-4 w-4/5 rounded animate-pulse" style={{ backgroundColor: 'var(--v-hover)' }} />
          </div>
        ) : (
          <div className="h-full flex items-center justify-center p-8">
            <TactileButton variant="solid" onClick={() => navigate('/articles/new')}>
              写长文
            </TactileButton>
          </div>
        )}
      </main>

      <SettingsModal open={settingsOpen} onClose={() => setSettingsOpen(false)} />
    </div>
  );
}
