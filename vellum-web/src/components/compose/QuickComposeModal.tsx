import { useEffect, useRef, useState } from 'react';
import { Calendar, MapPin } from 'lucide-react';
import { detectCurrentCity } from '@/lib/geolocation';
import {
  formatDatetimeLabel,
  fromLocalInputValue,
  toLocalInputValue,
} from '@/lib/utils';
import { useCreatePost } from '@/hooks/usePosts';
import { Modal } from '@/components/ui/Modal';
import { TactileButton } from '@/components/ui/TactileButton';
import { CityPickerModal } from './CityPickerModal';
import type { PostItem } from '@/types/api';

interface QuickComposeModalProps {
  open: boolean;
  onClose: () => void;
  onCreated?: (post: PostItem) => void;
}

export function QuickComposeModal({ open, onClose, onCreated }: QuickComposeModalProps) {
  const [content, setContent] = useState('');
  const [city, setCity] = useState<string | null>(null);
  const [recordTime, setRecordTime] = useState(() => new Date().toISOString());
  const [cityPickerOpen, setCityPickerOpen] = useState(false);
  const [editingTime, setEditingTime] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const createMutation = useCreatePost();

  useEffect(() => {
    if (!open) return;
    let cancelled = false;

    setContent('');
    setCity(null);
    setRecordTime(new Date().toISOString());
    setEditingTime(false);
    setCityPickerOpen(false);
    setErrorMsg(null);

    const timer = window.setTimeout(() => textareaRef.current?.focus(), 60);

    void detectCurrentCity().then((res) => {
      if (cancelled) return;
      if (res.city) {
        setCity(res.city);
      } else if (res.failed) {
        setCityPickerOpen(true);
      }
    });

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [open]);

  const handleSubmit = async () => {
    const trimmed = content.trim();
    if (!trimmed) {
      textareaRef.current?.focus();
      return;
    }
    setErrorMsg(null);
    try {
      const created = await createMutation.mutateAsync({
        type: 'MOMENT',
        title: null,
        content: trimmed,
        locationCity: city,
        recordTime,
      });
      onCreated?.(created);
      onClose();
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : '发布失败');
    }
  };

  return (
    <>
      <Modal open={open} onClose={onClose} maxWidthClass="max-w-[520px]">
        <div className="p-5 pb-3">
          <textarea
            ref={textareaRef}
            rows={5}
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="此刻..."
            className="w-full resize-none border-0 outline-none bg-transparent text-[15px] leading-[1.8]"
            style={{ color: 'var(--v-ink)' }}
          />
          {errorMsg && (
            <div className="mt-2 text-[12.5px] text-[#dc2626]">{errorMsg}</div>
          )}
        </div>

        <div
          className="px-5 py-3.5 border-t flex flex-wrap items-center justify-between gap-2"
          style={{ borderColor: 'var(--v-border)' }}
        >
          <div className="flex items-center gap-1.5 flex-wrap">
            <button
              type="button"
              onClick={() => setCityPickerOpen(true)}
              className="inline-flex items-center gap-1.5 px-2.5 h-7 rounded-full text-[12px] cursor-pointer transition-opacity hover:opacity-80"
              style={{
                backgroundColor: 'var(--v-track)',
                color: city ? 'var(--v-ink-secondary)' : 'var(--v-muted)',
              }}
            >
              <MapPin className="w-3 h-3" />
              <span>{city || '城市'}</span>
            </button>

            {editingTime ? (
              <input
                type="datetime-local"
                value={toLocalInputValue(recordTime)}
                onChange={(e) => {
                  if (e.target.value) {
                    setRecordTime(fromLocalInputValue(e.target.value));
                  }
                }}
                onBlur={() => setEditingTime(false)}
                autoFocus
                className="h-7 px-2.5 rounded-full text-[12px] tabular-nums outline-none border"
                style={{
                  backgroundColor: 'var(--v-track)',
                  borderColor: 'var(--v-border)',
                  color: 'var(--v-ink-secondary)',
                }}
              />
            ) : (
              <button
                type="button"
                onClick={() => setEditingTime(true)}
                className="inline-flex items-center gap-1.5 px-2.5 h-7 rounded-full text-[12px] tabular-nums cursor-pointer transition-opacity hover:opacity-80"
                style={{
                  backgroundColor: 'var(--v-track)',
                  color: 'var(--v-ink-secondary)',
                }}
              >
                <Calendar className="w-3 h-3" />
                <span>{formatDatetimeLabel(recordTime)}</span>
              </button>
            )}
          </div>

          <div className="flex items-center gap-2">
            <TactileButton variant="ghost" size="sm" onClick={onClose}>
              取消
            </TactileButton>
            <TactileButton
              variant="solid"
              size="sm"
              loading={createMutation.isPending}
              onClick={handleSubmit}
            >
              发布
            </TactileButton>
          </div>
        </div>
      </Modal>

      <CityPickerModal
        open={cityPickerOpen}
        currentCity={city}
        onSelect={setCity}
        onClose={() => setCityPickerOpen(false)}
      />
    </>
  );
}
