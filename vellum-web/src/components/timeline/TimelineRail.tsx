import { useMemo } from 'react';
import {
  cn,
  formatDay,
  formatMonthKey,
  formatTime,
  formatWeekday,
  stripMarkdown,
} from '@/lib/utils';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

interface TimelineRailProps {
  posts: PostItem[];
  selectedId: string | null;
  onSelect: (post: PostItem) => void;
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
  hasNextPage,
  isFetchingNextPage,
  onLoadMore,
  isLoading,
  className,
}: TimelineRailProps) {
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

  return (
    <aside
      className={cn(
        'subtle-scroll w-full md:w-[360px] shrink-0 border-r flex flex-col overflow-y-auto select-none transition-colors duration-200',
        className,
      )}
      style={{
        backgroundColor: 'var(--v-rail)',
        borderColor: 'var(--v-border)',
      }}
    >
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
                            <div
                              className="text-[13.5px] font-semibold truncate"
                              style={{ color: 'var(--v-ink)' }}
                            >
                              {item.title || '无题'}
                            </div>
                            <div
                              className="text-[12px] truncate mt-0.5"
                              style={{ color: 'var(--v-muted)' }}
                            >
                              {stripMarkdown(item.content)}
                            </div>
                          </>
                        ) : (
                          <div
                            className="text-[13px] leading-[1.45] line-clamp-2"
                            style={{ color: 'var(--v-ink)' }}
                          >
                            {item.content}
                          </div>
                        )}
                        <div
                          className="text-[11.5px] mt-1 tabular-nums"
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
                          <img src={thumb} alt="" className="w-full h-full object-cover" loading="lazy" />
                        </div>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}

          {hasNextPage && (
            <div className="px-4 pt-3 flex justify-center">
              <TactileButton
                variant="ghost"
                size="sm"
                loading={isFetchingNextPage}
                onClick={onLoadMore}
              >
                加载更多
              </TactileButton>
            </div>
          )}
        </div>
      )}
    </aside>
  );
}
