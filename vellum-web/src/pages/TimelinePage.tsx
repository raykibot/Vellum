import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { cn } from '@/lib/utils';
import { flattenPosts, useDeletePost, usePostsTimeline } from '@/hooks/usePosts';
import { QuickComposeModal } from '@/components/compose/QuickComposeModal';
import { TopNav } from '@/components/layout/TopNav';
import { SettingsModal } from '@/components/settings/SettingsModal';
import { MomentDetail } from '@/components/timeline/MomentDetail';
import { TimelineRail } from '@/components/timeline/TimelineRail';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

export function TimelinePage() {
  const navigate = useNavigate();
  const { data, isLoading, hasNextPage, isFetchingNextPage, fetchNextPage } = usePostsTimeline();
  const deleteMutation = useDeletePost();

  const posts = useMemo(() => flattenPosts(data), [data]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [mobileShowDetail, setMobileShowDetail] = useState(false);
  const [composeOpen, setComposeOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);

  useEffect(() => {
    if (posts.length === 0) {
      setSelectedId(null);
      return;
    }
    const current = posts.find((p) => p.id === selectedId);
    if (!current || current.type !== 'MOMENT') {
      const firstMoment = posts.find((p) => p.type === 'MOMENT');
      if (firstMoment) {
        setSelectedId(firstMoment.id);
      }
    }
  }, [posts, selectedId]);

  const activeMoment = useMemo(
    () => posts.find((p) => p.id === selectedId && p.type === 'MOMENT') ?? null,
    [posts, selectedId],
  );

  const handleSelectPost = (item: PostItem) => {
    if (item.type === 'ARTICLE') {
      navigate(`/articles/${item.id}`);
      return;
    }
    setSelectedId(item.id);
    setMobileShowDetail(true);
  };

  const handleDeleteMoment = async (id: string) => {
    const remainingMoments = posts.filter((p) => p.type === 'MOMENT' && p.id !== id);
    await deleteMutation.mutateAsync(id);
    setSelectedId(remainingMoments[0]?.id ?? null);
    setMobileShowDetail(false);
  };

  return (
    <div
      className="h-screen w-full flex flex-col overflow-hidden"
      style={{ backgroundColor: 'var(--v-canvas)', color: 'var(--v-ink)' }}
    >
      <TopNav
        activeTab="moment"
        primaryActionLabel="写一条"
        onPrimaryAction={() => setComposeOpen(true)}
        onOpenSettings={() => setSettingsOpen(true)}
      />

      <main className="flex-1 flex min-h-0">
        <TimelineRail
          posts={posts}
          selectedId={selectedId}
          onSelect={handleSelectPost}
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
          {activeMoment ? (
            <MomentDetail
              post={activeMoment}
              isDeleting={deleteMutation.isPending}
              onDelete={handleDeleteMoment}
              onMobileBack={() => setMobileShowDetail(false)}
            />
          ) : !isLoading && posts.length === 0 ? (
            <div className="h-full flex items-center justify-center p-8">
              <TactileButton variant="solid" onClick={() => setComposeOpen(true)}>
                写一条
              </TactileButton>
            </div>
          ) : null}
        </section>
      </main>

      <QuickComposeModal
        open={composeOpen}
        onClose={() => setComposeOpen(false)}
        onCreated={(created) => {
          setSelectedId(created.id);
          setMobileShowDetail(true);
        }}
      />

      <SettingsModal open={settingsOpen} onClose={() => setSettingsOpen(false)} />
    </div>
  );
}
