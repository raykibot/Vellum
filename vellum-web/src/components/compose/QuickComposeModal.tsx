import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type ClipboardEvent,
  type DragEvent,
} from 'react';
import { Calendar, ImagePlus, MapPin, X } from 'lucide-react';
import { uploadImage } from '@/api/files';
import { detectCurrentCity } from '@/lib/geolocation';
import {
  cn,
  formatDatetimeLabel,
  fromLocalInputValue,
  toLocalInputValue,
} from '@/lib/utils';
import { useCreatePost } from '@/hooks/usePosts';
import { Modal } from '@/components/ui/Modal';
import { TactileButton } from '@/components/ui/TactileButton';
import { CityPickerModal } from './CityPickerModal';
import type { PostItem } from '@/types/api';

const MAX_IMAGES = 9;
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp']);

interface PendingImage {
  localId: string;
  file: File;
  previewUrl: string;
  uploadedId?: string;
}

interface QuickComposeModalProps {
  open: boolean;
  onClose: () => void;
  onCreated?: (post: PostItem) => void;
}

function isSupportedImage(file: File): boolean {
  const mime = file.type.toLowerCase();
  if (mime) {
    return ALLOWED_MIME_TYPES.has(mime);
  }
  return /\.(jpe?g|png|webp)$/i.test(file.name);
}

export function QuickComposeModal({ open, onClose, onCreated }: QuickComposeModalProps) {
  const [content, setContent] = useState('');
  const [city, setCity] = useState<string | null>(null);
  const [recordTime, setRecordTime] = useState(() => new Date().toISOString());
  const [pendingImages, setPendingImages] = useState<PendingImage[]>([]);
  const [cityPickerOpen, setCityPickerOpen] = useState(false);
  const [editingTime, setEditingTime] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pendingImagesRef = useRef<PendingImage[]>([]);
  pendingImagesRef.current = pendingImages;

  const createMutation = useCreatePost();

  const revokeImages = useCallback((items: PendingImage[]) => {
    for (const item of items) {
      URL.revokeObjectURL(item.previewUrl);
    }
  }, []);

  useEffect(() => {
    return () => {
      revokeImages(pendingImagesRef.current);
    };
  }, [revokeImages]);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;

    revokeImages(pendingImagesRef.current);
    setPendingImages([]);
    setContent('');
    setCity(null);
    setRecordTime(new Date().toISOString());
    setEditingTime(false);
    setCityPickerOpen(false);
    setIsDragging(false);
    setSubmitting(false);
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
  }, [open, revokeImages]);

  const appendFiles = useCallback((files: FileList | File[]) => {
    const incoming = Array.from(files);
    if (incoming.length === 0) return;

    const validFiles: File[] = [];
    let rejection: string | null = null;

    for (const file of incoming) {
      if (!isSupportedImage(file)) {
        rejection = '仅支持 JPG、PNG、WebP 格式图片';
        continue;
      }
      if (file.size > MAX_IMAGE_BYTES) {
        rejection = '单张图片大小不能超过 20MB';
        continue;
      }
      validFiles.push(file);
    }

    if (validFiles.length > 0) {
      setPendingImages((prev) => {
        const remaining = MAX_IMAGES - prev.length;
        if (remaining <= 0) return prev;
        const accepted = validFiles.slice(0, remaining).map((file) => ({
          localId: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
          file,
          previewUrl: URL.createObjectURL(file),
        }));
        return [...prev, ...accepted];
      });
    }

    setErrorMsg(rejection);
  }, []);

  const handleFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    if (event.target.files) {
      appendFiles(event.target.files);
    }
    event.target.value = '';
  };

  const handlePaste = (event: ClipboardEvent<HTMLDivElement>) => {
    const items = event.clipboardData?.items;
    if (!items) return;
    const files: File[] = [];
    for (const item of items) {
      if (item.kind === 'file' && item.type.startsWith('image/')) {
        const file = item.getAsFile();
        if (file) files.push(file);
      }
    }
    if (files.length > 0) {
      event.preventDefault();
      appendFiles(files);
    }
  };

  const handleDrop = (event: DragEvent<HTMLDivElement>) => {
    event.preventDefault();
    setIsDragging(false);
    if (event.dataTransfer?.files?.length) {
      appendFiles(event.dataTransfer.files);
    }
  };

  const removeImage = (localId: string) => {
    setPendingImages((prev) => {
      const target = prev.find((item) => item.localId === localId);
      if (target) {
        URL.revokeObjectURL(target.previewUrl);
      }
      return prev.filter((item) => item.localId !== localId);
    });
  };

  const handleClose = () => {
    if (submitting) return;
    revokeImages(pendingImagesRef.current);
    setPendingImages([]);
    onClose();
  };

  const handleSubmit = async () => {
    const trimmed = content.trim();
    const snapshot = [...pendingImages];
    if (!trimmed && snapshot.length === 0) {
      textareaRef.current?.focus();
      return;
    }

    setErrorMsg(null);
    setSubmitting(true);
    try {
      const uploadedMap = new Map<string, string>();
      const needUpload = snapshot.filter((img) => !img.uploadedId);

      if (needUpload.length > 0) {
        const settled = await Promise.allSettled(
          needUpload.map(async (img) => ({
            localId: img.localId,
            id: (await uploadImage(img.file)).id,
          })),
        );

        let firstError: string | null = null;
        for (const result of settled) {
          if (result.status === 'fulfilled') {
            uploadedMap.set(result.value.localId, result.value.id);
          } else if (!firstError) {
            firstError = result.reason instanceof Error ? result.reason.message : '图片上传失败';
          }
        }

        if (uploadedMap.size > 0) {
          setPendingImages((prev) =>
            prev.map((item) => {
              const id = uploadedMap.get(item.localId);
              return id ? { ...item, uploadedId: id } : item;
            }),
          );
        }

        if (firstError) {
          throw new Error(firstError);
        }
      }

      const imageIds =
        snapshot.length > 0
          ? snapshot.map((img) => img.uploadedId ?? uploadedMap.get(img.localId)!)
          : undefined;

      const created = await createMutation.mutateAsync({
        type: 'MOMENT',
        title: null,
        content: trimmed,
        locationCity: city,
        recordTime,
        imageIds,
      });

      revokeImages(pendingImagesRef.current);
      setPendingImages([]);
      onCreated?.(created);
      onClose();
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : '发布失败');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Modal open={open} onClose={handleClose} maxWidthClass="max-w-[520px]">
        <div
          onPaste={handlePaste}
          onDragOver={(e) => {
            e.preventDefault();
            setIsDragging(true);
          }}
          onDragLeave={(e) => {
            if (e.currentTarget === e.target) {
              setIsDragging(false);
            }
          }}
          onDrop={handleDrop}
          className={cn('transition-colors', isDragging && 'ring-1 ring-inset ring-[var(--v-ink)]')}
        >
          <div className="p-5 pb-3">
            <textarea
              ref={textareaRef}
              rows={pendingImages.length > 0 ? 4 : 5}
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="此刻..."
              className="w-full resize-none border-0 outline-none bg-transparent text-[15px] leading-[1.8]"
              style={{ color: 'var(--v-ink)' }}
            />

            {pendingImages.length > 0 && (
              <div className="mt-3 grid grid-cols-3 sm:grid-cols-5 gap-2">
                {pendingImages.map((img) => (
                  <div
                    key={img.localId}
                    className="relative aspect-square rounded-xl overflow-hidden border group"
                    style={{ borderColor: 'var(--v-border)' }}
                  >
                    <img
                      src={img.previewUrl}
                      alt=""
                      className="w-full h-full object-cover"
                    />
                    {!submitting && (
                      <button
                        type="button"
                        aria-label="移除图片"
                        onClick={() => removeImage(img.localId)}
                        className="absolute top-1.5 right-1.5 w-5 h-5 rounded-full bg-black/55 text-white flex items-center justify-center backdrop-blur-sm opacity-90 hover:opacity-100 transition-opacity cursor-pointer"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    )}
                  </div>
                ))}
              </div>
            )}

            {errorMsg && (
              <div className="mt-2 text-[12.5px] text-[#dc2626]">{errorMsg}</div>
            )}
          </div>

          <div
            className="px-5 py-3.5 border-t flex flex-wrap items-center justify-between gap-2"
            style={{ borderColor: 'var(--v-border)' }}
          >
            <div className="flex items-center gap-1.5 flex-wrap">
              {pendingImages.length < MAX_IMAGES && (
                <button
                  type="button"
                  aria-label="添加图片"
                  disabled={submitting}
                  onClick={() => fileInputRef.current?.click()}
                  className="inline-flex items-center justify-center w-7 h-7 rounded-full cursor-pointer transition-opacity hover:opacity-80 disabled:opacity-50"
                  style={{
                    backgroundColor: 'var(--v-track)',
                    color: 'var(--v-ink-secondary)',
                  }}
                >
                  <ImagePlus className="w-3.5 h-3.5" />
                </button>
              )}

              <input
                ref={fileInputRef}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                multiple
                onChange={handleFileChange}
                className="hidden"
              />

              <button
                type="button"
                disabled={submitting}
                onClick={() => setCityPickerOpen(true)}
                className="inline-flex items-center gap-1.5 px-2.5 h-7 rounded-full text-[12px] cursor-pointer transition-opacity hover:opacity-80 disabled:opacity-50"
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
                  disabled={submitting}
                  onClick={() => setEditingTime(true)}
                  className="inline-flex items-center gap-1.5 px-2.5 h-7 rounded-full text-[12px] tabular-nums cursor-pointer transition-opacity hover:opacity-80 disabled:opacity-50"
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
              <TactileButton variant="ghost" size="sm" disabled={submitting} onClick={handleClose}>
                取消
              </TactileButton>
              <TactileButton
                variant="solid"
                size="sm"
                loading={submitting}
                onClick={handleSubmit}
              >
                发布
              </TactileButton>
            </div>
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
