import { useEffect, useRef, useState } from 'react';
import { motion } from 'motion/react';
import { ArrowLeft, Check, Download, Trash2 } from 'lucide-react';
import { downloadPostFile } from '@/lib/fileIo';
import { formatFullDate, formatTime } from '@/lib/utils';
import { PhotoGallery } from '@/components/media/PhotoGallery';
import { Modal } from '@/components/ui/Modal';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

interface MomentDetailProps {
  post: PostItem;
  onDelete: (id: string) => Promise<void>;
  isDeleting: boolean;
  onMobileBack?: () => void;
}

export function MomentDetail({
  post,
  onDelete,
  isDeleting,
  onMobileBack,
}: MomentDetailProps) {
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
    ? `${formatFullDate(post.recordTime)} · ${formatTime(post.recordTime)} · ${post.locationCity}`
    : `${formatFullDate(post.recordTime)} · ${formatTime(post.recordTime)}`;

  const paragraphs = post.content
    .replace(/\r\n/g, '\n')
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean);

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
      <motion.div
        key={post.id}
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.24, ease: [0.22, 1, 0.36, 1] }}
        className="max-w-[660px] mx-auto px-6 md:px-10 py-8"
      >
        <div
          className="flex items-center justify-between pb-5 mb-6 border-b"
          style={{ borderColor: 'var(--v-border)' }}
        >
          <div className="flex items-center gap-2 min-w-0">
            {onMobileBack && (
              <TactileButton
                variant="ghost"
                size="icon"
                aria-label="返回列表"
                onClick={onMobileBack}
                className="md:hidden -ml-2"
              >
                <ArrowLeft className="w-4 h-4" />
              </TactileButton>
            )}
            <span className="text-[13px] tabular-nums truncate" style={{ color: 'var(--v-muted)' }}>
              {meta}
            </span>
          </div>

          <div className="flex items-center gap-1 shrink-0">
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

        {paragraphs.length > 0 && (
          <div className="space-y-3.5 text-[15.5px] leading-[1.85]" style={{ color: 'var(--v-ink)' }}>
            {paragraphs.map((paragraph, idx) => (
              <p key={idx}>{paragraph}</p>
            ))}
          </div>
        )}

        {post.images && post.images.length > 0 && (
          <PhotoGallery
            images={post.images}
            className={paragraphs.length > 0 ? 'mt-5' : 'mt-0'}
          />
        )}
      </motion.div>

      <Modal open={deleteConfirmOpen} onClose={() => setDeleteConfirmOpen(false)} maxWidthClass="max-w-[320px]">
        <div className="p-5">
          <div className="text-[15px] font-semibold" style={{ color: 'var(--v-ink)' }}>
            删除这条记录
          </div>
          <div className="mt-5 flex items-center justify-end gap-2">
            <TactileButton
              variant="ghost"
              size="sm"
              onClick={() => setDeleteConfirmOpen(false)}
            >
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
