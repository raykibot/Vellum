import { useEffect, useMemo, useRef, type ChangeEvent } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { Plus, Upload } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { parseMarkdownOrTextFile } from '@/lib/fileIo';
import { cn, formatMonthKey, formatShortDate } from '@/lib/utils';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

interface ArticleDrawerProps {
  open: boolean;
  onClose: () => void;
  articles: PostItem[];
  activeId?: string;
}

interface ArticleMonthGroup {
  month: string;
  items: PostItem[];
}

export function ArticleDrawer({ open, onClose, articles, activeId }: ArticleDrawerProps) {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!open) return;
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [open, onClose]);

  const groups = useMemo<ArticleMonthGroup[]>(() => {
    const map = new Map<string, PostItem[]>();
    for (const article of articles) {
      const month = formatMonthKey(article.recordTime);
      const list = map.get(month);
      if (list) {
        list.push(article);
      } else {
        map.set(month, [article]);
      }
    }
    return Array.from(map.entries()).map(([month, items]) => ({ month, items }));
  }, [articles]);

  const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    const parsed = await parseMarkdownOrTextFile(file);
    onClose();
    navigate('/articles/new', {
      state: {
        importedTitle: parsed.title,
        importedContent: parsed.content,
      },
    });
  };

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            onClick={onClose}
            className="fixed top-[52px] inset-x-0 bottom-0 z-20 bg-black/8"
          />

          <motion.aside
            initial={{ x: -280, opacity: 0.6 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: -280, opacity: 0.6 }}
            transition={{ type: 'spring', stiffness: 420, damping: 36 }}
            className="fixed top-[52px] left-0 bottom-0 z-30 w-[280px] border-r backdrop-blur-2xl flex flex-col select-none"
            style={{
              backgroundColor: 'var(--v-drawer)',
              borderColor: 'var(--v-border)',
              boxShadow: '12px 0 36px rgba(0, 0, 0, 0.08)',
            }}
          >
            <div
              className="h-11 px-3 flex items-center justify-between border-b shrink-0"
              style={{ borderColor: 'var(--v-border)' }}
            >
              <span className="text-[13px] font-semibold px-1.5" style={{ color: 'var(--v-ink)' }}>
                长文
              </span>
              <div className="flex items-center gap-0.5">
                <TactileButton
                  variant="ghost"
                  size="icon"
                  aria-label="导入文档"
                  onClick={() => fileInputRef.current?.click()}
                >
                  <Upload className="w-[15px] h-[15px]" strokeWidth={1.8} />
                </TactileButton>
                <TactileButton
                  variant="ghost"
                  size="icon"
                  aria-label="新建长文"
                  onClick={() => {
                    onClose();
                    navigate('/articles/new');
                  }}
                >
                  <Plus className="w-4 h-4" strokeWidth={1.9} />
                </TactileButton>
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept=".md,.markdown,.txt"
                onChange={handleFileChange}
                className="hidden"
              />
            </div>

            <div className="flex-1 overflow-y-auto subtle-scroll py-2 px-2">
              {groups.map((group) => (
                <div key={group.month} className="mb-3">
                  <div
                    className="px-2.5 py-1.5 text-[12px] font-medium"
                    style={{ color: 'var(--v-muted)' }}
                  >
                    {group.month}
                  </div>
                  <div className="space-y-0.5">
                    {group.items.map((article) => {
                      const active = article.id === activeId;
                      return (
                        <button
                          key={article.id}
                          type="button"
                          onClick={() => {
                            onClose();
                            navigate(`/articles/${article.id}`);
                          }}
                          className={cn(
                            'w-full px-2.5 py-2 rounded-lg flex items-center justify-between gap-2 text-left cursor-pointer transition-colors duration-150',
                            !active && 'hover:bg-[var(--v-hover)]',
                          )}
                          style={{
                            backgroundColor: active ? 'var(--v-selected)' : 'transparent',
                            boxShadow: active ? 'var(--v-selected-shadow)' : 'none',
                          }}
                        >
                          <span
                            className="text-[13px] truncate"
                            style={{
                              color: 'var(--v-ink)',
                              fontWeight: active ? 600 : 400,
                            }}
                          >
                            {article.title || '无题'}
                          </span>
                          <span
                            className="text-[12px] tabular-nums shrink-0"
                            style={{ color: 'var(--v-muted)' }}
                          >
                            {formatShortDate(article.recordTime)}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
  );
}
