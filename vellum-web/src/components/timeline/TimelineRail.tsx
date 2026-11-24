import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  type ChangeEvent,
  type WheelEvent,
} from 'react';
import { FileText, Upload } from 'lucide-react';
import { parseMarkdownOrTextFile } from '@/lib/fileIo';
import { resolveMediaUrl } from '@/lib/storage';
import {
  cn,
  formatDay,
  formatMonthKey,
  formatTime,
  formatWeekday,
  stripMarkdown,
} from '@/lib/utils';
import type { PostFilter } from '@/hooks/usePosts';
import { SegmentedControl } from '@/components/ui/SegmentedControl';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

const FILTER_OPTIONS = [
  { value: 'all', label: '全部' },
  { value: 'moment', label: '动态' },
  { value: 'article', label: '长文' },
] as const;

interface TimelineRailProps {
  posts: PostItem[];
  selectedId: string | null;
  onSelect: (post: PostItem) => void;
  filter: PostFilter;
  onFilterChange: (filter: PostFilter) => void;
  sidebarOpen: boolean;
  onImportArticleFile: (parsed: { title: string; content: string }) => void;
  hasNextPage: boolean;
  isFetchingNextPage: boolean;
  onLoadMore: () => void;
  isLoading: boolean;
  className?: string;
}

interface MonthGroup {
  month: string;
  items: PostItem[];
}

export function TimelineRail({
  posts,
  selectedId,
  onSelect,
  filter,
  onFilterChange,
  sidebarOpen,
  onImportArticleFile,
  hasNextPage,
  isFetchingNextPage,
  onLoadMore,
  isLoading,
  className,
}: TimelineRailProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const hasUserScrolledRef = useRef(false);

  const groups = useMemo<MonthGroup[]>(() => {
    const map = new Map<string, PostItem[]>();
    for (const post of posts) {
      const month = formatMonthKey(post.recordTime);
      const list = map.get(month);
      if (list) {
        list.push(post);
      } else {
        map.set(month, [post]);
      }
    }
    return Array.from(map.entries()).map(([month, items]) => ({ month, items }));
  }, [posts]);

  const maybeLoadMore = useCallback(() => {
    if (!hasUserScrolledRef.current) return;
    if (!hasNextPage || isFetchingNextPage || isLoading) return;
    onLoadMore();
  }, [hasNextPage, isFetchingNextPage, isLoading, onLoadMore]);

  useEffect(() => {
    hasUserScrolledRef.current = false;
    if (scrollRef.current) {
      scrollRef.current.scrollTop = 0;
    }
  }, [filter]);

  useEffect(() => {
    const rootEl = scrollRef.current;
    const targetEl = sentinelRef.current;
    if (!rootEl || !targetEl || !hasNextPage) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          maybeLoadMore();
        }
      },
      {
        root: rootEl,
        rootMargin: '0px 0px 100px 0px',
      },
    );

    observer.observe(targetEl);
    return () => observer.disconnect();
  }, [hasNextPage, maybeLoadMore, posts.length]);

  const handleScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    if (el.scrollTop > 16) {
      hasUserScrolledRef.current = true;
    }
    if (el.scrollHeight - el.scrollTop - el.clientHeight <= 100) {
      maybeLoadMore();
    }
  };

  const handleWheel = (event: WheelEvent<HTMLDivElement>) => {
    if (event.deltaY > 0) {
      hasUserScrolledRef.current = true;
    }
  };

  const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    const parsed = await parseMarkdownOrTextFile(file);
    onImportArticleFile(parsed);
  };

  const emptyLabel =
    filter === 'moment' ? '暂无动态' : filter === 'article' ? '暂无长文' : '暂无记录';

  return (
    <aside
      aria-hidden={!sidebarOpen ? true : undefined}
      className={cn(
        'shrink-0 overflow-hidden transition-all duration-250 ease-out select-none',
        sidebarOpen
          ? 'w-full md:w-[360px] md:opacity-100 border-r'
          : 'w-full md:w-0 md:opacity-0 md:border-r-0 md:pointer-events-none',
        className,
      )}
      style={{
        backgroundColor: 'var(--v-rail)',
        borderColor: 'var(--v-border)',
      }}
    >
      <div
        ref={scrollRef}
        onScroll={handleScroll}
        onWheel={handleWheel}
        className="w-full md:w-[360px] h-full overflow-y-auto subtle-scroll flex flex-col"
      >
        {/* Sticky filter + import header */}
        <div
          className="sticky top-0 z-10 px-3 py-2.5 border-b flex items-center justify-between gap-2 backdrop-blur-xl shrink-0"
          style={{
            backgroundColor: 'var(--v-drawer)',
            borderColor: 'var(--v-border)',
          }}
        >
          <SegmentedControl
            options={FILTER_OPTIONS}
            value={filter}
            onChange={onFilterChange}
            size="sm"
            layoutId="rail-filter-thumb"
          />

          <TactileButton
            variant="ghost"
            size="icon"
            aria-label="导入 Markdown 或文本"
            title="导入 .md / .txt 为长文"
            onClick={() => fileInputRef.current?.click()}
          >
            <Upload className="w-[15px] h-[15px]" strokeWidth={1.8} />
          </TactileButton>
          <input
            ref={fileInputRef}
            type="file"
            accept=".md,.markdown,.txt"
            onChange={handleFileChange}
            className="hidden"
          />
        </div>

        {isLoading ? (
          <div className="px-3 pt-4 space-y-2">
            {[0, 1, 2, 3].map((idx) => (
              <div
                key={idx}
                className="h-[74px] rounded-xl animate-pulse"
                style={{ backgroundColor: 'var(--v-hover)' }}
              />
            ))}
          </div>
        ) : posts.length === 0 ? (
          <div
            className="flex-1 flex items-center justify-center p-6 text-[13px]"
            style={{ color: 'var(--v-muted)' }}
          >
            {emptyLabel}
          </div>
        ) : (
          <div className="pb-6">
            {groups.map((group) => (
              <div key={group.month}>
                <div className="px-5 pt-4 pb-2">
                  <h2
                    className="text-[13px] font-semibold tracking-tight"
                    style={{ color: 'var(--v-ink)' }}
                  >
                    {group.month}
                  </h2>
                </div>

                <div className="px-2.5 space-y-1">
                  {group.items.map((item) => {
                    const selected = item.id === selectedId;
                    const thumb = item.images?.[0];
                    const meta = item.locationCity
                      ? `${formatTime(item.recordTime)} · ${item.locationCity}`
                      : formatTime(item.recordTime);

                    return (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => onSelect(item)}
                        className={cn(
                          'w-full text-left px-3 py-3 rounded-xl flex items-center gap-2.5 cursor-pointer transition-all duration-150 active:scale-[0.992]',
                          !selected && 'hover:bg-[var(--v-hover)]',
                        )}
                        style={{
                          backgroundColor: selected ? 'var(--v-selected)' : 'transparent',
                          boxShadow: selected ? 'var(--v-selected-shadow)' : 'none',
                        }}
                      >
                        <div className="w-[34px] shrink-0 text-center tabular-nums leading-none">
                          <div className="text-[11px]" style={{ color: 'var(--v-muted)' }}>
                            {formatWeekday(item.recordTime)}
                          </div>
                          <div
                            className="text-[19px] font-semibold mt-1"
                            style={{ color: 'var(--v-ink)' }}
                          >
                            {formatDay(item.recordTime)}
                          </div>
                        </div>

                        <div className="flex-1 min-w-0">
                          {item.type === 'ARTICLE' ? (
                            <>
                              <div className="flex items-center gap-1.5 min-w-0">
                                <FileText
                                  className="w-3.5 h-3.5 shrink-0"
                                  strokeWidth={1.8}
                                  style={{ color: 'var(--v-muted)' }}
                                />
                                <span
                                  className="text-[13.5px] font-semibold truncate"
                                  style={{ color: 'var(--v-ink)' }}
                                >
                                  {item.title || '无题'}
                                </span>
                              </div>
                              <div
                                className="text-[12px] truncate mt-0.5"
                                style={{ color: 'var(--v-muted)' }}
                              >
                                {stripMarkdown(item.content)}
                              </div>
                            </>
                          ) : item.content.trim() ? (
                            <div
                              className="text-[13px] leading-[1.45] line-clamp-2"
                              style={{ color: 'var(--v-ink)' }}
                            >
                              {item.content}
                            </div>
                          ) : null}
                          <div
                            className={cn(
                              'text-[11.5px] tabular-nums',
                              (item.type === 'ARTICLE' || item.content.trim()) && 'mt-1',
                            )}
                            style={{ color: 'var(--v-muted)' }}
                          >
                            {meta}
                          </div>
                        </div>

                        {thumb && (
                          <div
                            className="w-[54px] h-[54px] rounded-[10px] shrink-0 overflow-hidden border"
                            style={{ borderColor: 'var(--v-border)' }}
                          >
                            <img
                              src={resolveMediaUrl(thumb)}
                              alt=""
                              className="w-full h-full object-cover"
                              loading="lazy"
                            />
                          </div>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}

            {isFetchingNextPage && (
              <div className="px-2.5 pt-1 space-y-1">
                {[0, 1].map((idx) => (
                  <div
                    key={idx}
                    className="h-[74px] rounded-xl animate-pulse"
                    style={{ backgroundColor: 'var(--v-hover)' }}
                  />
                ))}
              </div>
            )}

            <div ref={sentinelRef} className="h-1 shrink-0" aria-hidden="true" />
          </div>
        )}
      </div>
    </aside>
  );
}
