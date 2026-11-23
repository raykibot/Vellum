import { useEffect, useRef, useState } from 'react';
import { motion } from 'motion/react';
import { Check, Download, Trash2 } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { downloadPostFile } from '@/lib/fileIo';
import { formatFullDate, stripDuplicateLeadingHeading } from '@/lib/utils';
import { PhotoGallery } from '@/components/media/PhotoGallery';
import { Modal } from '@/components/ui/Modal';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

interface ArticleReaderProps {
  post: PostItem;
  onDelete: (id: string) => Promise<void>;
  isDeleting: boolean;
}

export function ArticleReader({ post, onDelete, isDeleting }: ArticleReaderProps) {
  const [exportMenuOpen, setExportMenuOpen] = useState(false);
  const [exported, setExported] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setExportMenuOpen(false);
    setExported(false);
  }, [post.id]);

  useEffect(() => {
    if (!exportMenuOpen) return;
    const handleOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setExportMenuOpen(false);
      }
    };
    window.addEventListener('mousedown', handleOutside);
    return () => window.removeEventListener('mousedown', handleOutside);
  }, [exportMenuOpen]);

  const meta = post.locationCity
    ? `${formatFullDate(post.recordTime)} · ${post.locationCity}`
    : formatFullDate(post.recordTime);

  const cleanBody = stripDuplicateLeadingHeading(post.content, post.title);

  const handleExport = (ext: 'md' | 'txt') => {
    downloadPostFile(post, ext);
    setExportMenuOpen(false);
    setExported(true);
    setTimeout(() => setExported(false), 1100);
  };

  const handleConfirmDelete = async () => {
    await onDelete(post.id);
    setDeleteConfirmOpen(false);
  };

  return (
    <>
      <motion.article
        key={post.id}
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
        className="max-w-[660px] mx-auto px-6 md:px-10 py-10 md:py-12"
      >
        <div
          className="flex items-center justify-between pb-4 mb-8 border-b"
          style={{ borderColor: 'var(--v-border)' }}
        >
          <span className="text-[13px] tabular-nums" style={{ color: 'var(--v-muted)' }}>
            {meta}
          </span>

          <div className="flex items-center gap-1">
            <div ref={menuRef} className="relative">
              <TactileButton
                variant="ghost"
                size="icon"
                aria-label="另存为"
                onClick={() => setExportMenuOpen((v) => !v)}
                style={exported ? { color: 'var(--v-ink)' } : undefined}
              >
                {exported ? <Check className="w-[15px] h-[15px]" /> : <Download className="w-[15px] h-[15px]" />}
              </TactileButton>

              {exportMenuOpen && (
                <div
                  className="absolute right-0 mt-1.5 w-28 rounded-xl border p-1 z-20"
                  style={{
                    backgroundColor: 'var(--v-canvas)',
                    borderColor: 'var(--v-border)',
                    boxShadow: '0 12px 32px rgba(0, 0, 0, 0.14)',
                  }}
                >
                  <button
                    type="button"
                    onClick={() => handleExport('md')}
                    className="w-full text-left px-3 py-1.5 rounded-lg text-[12.5px] hover:bg-[var(--v-hover)] cursor-pointer transition-colors"
                    style={{ color: 'var(--v-ink)' }}
                  >
                    导出 .md
                  </button>
                  <button
                    type="button"
                    onClick={() => handleExport('txt')}
                    className="w-full text-left px-3 py-1.5 rounded-lg text-[12.5px] hover:bg-[var(--v-hover)] cursor-pointer transition-colors"
                    style={{ color: 'var(--v-ink)' }}
                  >
                    导出 .txt
                  </button>
                </div>
              )}
            </div>

            <TactileButton
              variant="ghost"
              size="icon"
              aria-label="删除"
              onClick={() => setDeleteConfirmOpen(true)}
            >
              <Trash2 className="w-[15px] h-[15px]" />
            </TactileButton>
          </div>
        </div>

        <h1
          className="text-[28px] font-semibold tracking-tight leading-[1.3] mb-7"
          style={{ color: 'var(--v-ink)' }}
        >
          {post.title || '无题'}
        </h1>

        <div className="vellum-prose">
          <ReactMarkdown remarkPlugins={[remarkGfm]}>{cleanBody}</ReactMarkdown>
        </div>

        {post.images && post.images.length > 0 && (
          <div className="mt-8">
            <PhotoGallery images={post.images} />
          </div>
        )}
      </motion.article>

      <Modal open={deleteConfirmOpen} onClose={() => setDeleteConfirmOpen(false)} maxWidthClass="max-w-[320px]">
        <div className="p-5">
          <div className="text-[15px] font-semibold" style={{ color: 'var(--v-ink)' }}>
            删除这篇长文
          </div>
          <div className="mt-5 flex items-center justify-end gap-2">
            <TactileButton variant="ghost" size="sm" onClick={() => setDeleteConfirmOpen(false)}>
              取消
            </TactileButton>
            <TactileButton
              variant="danger"
              size="sm"
              loading={isDeleting}
              onClick={handleConfirmDelete}
            >
              删除
            </TactileButton>
          </div>
        </div>
      </Modal>
    </>
  );
}
