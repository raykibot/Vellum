import {
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
  type ChangeEvent,
  type DragEvent,
  type KeyboardEvent,
} from 'react';
import { Calendar, Columns2, MapPin, Upload } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { parseMarkdownOrTextFile } from '@/lib/fileIo';
import { detectCurrentCity } from '@/lib/geolocation';
import {
  cn,
  formatDatetimeLabel,
  fromLocalInputValue,
  toLocalInputValue,
} from '@/lib/utils';
import { useCreatePost } from '@/hooks/usePosts';
import { CityPickerModal } from '@/components/compose/CityPickerModal';
import { TactileButton } from '@/components/ui/TactileButton';
import type { PostItem } from '@/types/api';

export interface ArticleEditorHandle {
  submit: () => Promise<void>;
}

interface ArticleEditorProps {
  initialTitle?: string;
  initialContent?: string;
  onPublished: (post: PostItem) => void;
  onSubmittingChange?: (submitting: boolean) => void;
}

export const ArticleEditor = forwardRef<ArticleEditorHandle, ArticleEditorProps>(
  function ArticleEditor(
    { initialTitle = '', initialContent = '', onPublished, onSubmittingChange },
    ref,
  ) {
    const [title, setTitle] = useState(initialTitle);
    const [content, setContent] = useState(initialContent);
    const [city, setCity] = useState<string | null>(null);
    const [recordTime, setRecordTime] = useState(() => new Date().toISOString());
    const [splitPreview, setSplitPreview] = useState(false);
    const [cityPickerOpen, setCityPickerOpen] = useState(false);
    const [editingTime, setEditingTime] = useState(false);
    const [isTyping, setIsTyping] = useState(false);
    const [isDragging, setIsDragging] = useState(false);
    const [errorMsg, setErrorMsg] = useState<string | null>(null);

    const fileInputRef = useRef<HTMLInputElement>(null);
    const textareaRef = useRef<HTMLTextAreaElement>(null);
    const titleRef = useRef<HTMLInputElement>(null);

    const createMutation = useCreatePost();

    useEffect(() => {
      if (initialTitle || initialContent) {
        setTitle(initialTitle);
        setContent(initialContent);
      }
    }, [initialTitle, initialContent]);

    useEffect(() => {
      let cancelled = false;
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
      };
    }, []);

    useEffect(() => {
      onSubmittingChange?.(createMutation.isPending);
    }, [createMutation.isPending, onSubmittingChange]);

    useEffect(() => {
      const el = textareaRef.current;
      if (!el) return;
      el.style.height = 'auto';
      el.style.height = `${Math.max(el.scrollHeight, 360)}px`;
    }, [content, splitPreview]);

    useEffect(() => {
      const handlePointerMove = () => {
        if (isTyping) {
          setIsTyping(false);
        }
      };
      window.addEventListener('mousemove', handlePointerMove, { passive: true });
      return () => window.removeEventListener('mousemove', handlePointerMove);
    }, [isTyping]);

    const handleImportFile = async (file: File) => {
      if (!/\.(md|markdown|txt)$/i.test(file.name)) return;
      const parsed = await parseMarkdownOrTextFile(file);
      setTitle(parsed.title);
      setContent(parsed.content);
      setErrorMsg(null);
    };

    const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
      const file = event.target.files?.[0];
      event.target.value = '';
      if (file) {
        await handleImportFile(file);
      }
    };

    const handleDrop = async (event: DragEvent<HTMLDivElement>) => {
      event.preventDefault();
      setIsDragging(false);
      const file = event.dataTransfer.files?.[0];
      if (file) {
        await handleImportFile(file);
      }
    };

    const handleKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
      if (event.key === 'Tab') {
        event.preventDefault();
        const el = event.currentTarget;
        const start = el.selectionStart;
        const end = el.selectionEnd;
        const next = `${content.slice(0, start)}  ${content.slice(end)}`;
        setContent(next);
        requestAnimationFrame(() => {
          el.selectionStart = start + 2;
          el.selectionEnd = start + 2;
        });
      }
    };

    const submit = useCallback(async () => {
      const trimmedContent = content.trim();
      if (!trimmedContent) {
        textareaRef.current?.focus();
        return;
      }
      setErrorMsg(null);
      try {
        const created = await createMutation.mutateAsync({
          type: 'ARTICLE',
          title: title.trim() || null,
          content: trimmedContent,
          locationCity: city,
          recordTime,
        });
        onPublished(created);
      } catch (err) {
        setErrorMsg(err instanceof Error ? err.message : '发布失败');
      }
    }, [content, title, city, recordTime, createMutation, onPublished]);

    useImperativeHandle(ref, () => ({ submit }), [submit]);

    return (
      <>
        <div
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
          className={cn(
            'min-h-full px-6 md:px-10 py-8 transition-colors duration-200',
            isDragging && 'ring-1 ring-inset ring-[var(--v-ink)]',
          )}
        >
          <div className={cn('mx-auto', splitPreview ? 'max-w-[1160px]' : 'max-w-[660px]')}>
            {/* Subtle iA-style fading toolbar */}
            <div
              className={cn(
                'flex items-center justify-between gap-3 pb-5 mb-8 border-b transition-opacity duration-300',
                isTyping ? 'opacity-20 hover:opacity-100 focus-within:opacity-100' : 'opacity-100',
              )}
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

              <div className="flex items-center gap-1">
                <TactileButton
                  variant="ghost"
                  size="icon"
                  aria-label="导入 Markdown 或文本"
                  onClick={() => fileInputRef.current?.click()}
                >
                  <Upload className="w-[15px] h-[15px]" strokeWidth={1.8} />
                </TactileButton>
                <TactileButton
                  variant="ghost"
                  size="icon"
                  aria-label="分栏预览"
                  onClick={() => setSplitPreview((v) => !v)}
                  style={
                    splitPreview
                      ? { backgroundColor: 'var(--v-hover)', color: 'var(--v-ink)' }
                      : undefined
                  }
                >
                  <Columns2 className="w-[15px] h-[15px]" strokeWidth={1.8} />
                </TactileButton>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".md,.markdown,.txt"
                  onChange={handleFileChange}
                  className="hidden"
                />
              </div>
            </div>

            {errorMsg && (
              <div className="mb-4 text-[13px] text-[#dc2626]">{errorMsg}</div>
            )}

            <div className={cn(splitPreview && 'grid grid-cols-1 lg:grid-cols-2 gap-10')}>
              <div className="min-w-0">
                <div className="flex items-baseline mb-6">
                  <span
                    aria-hidden="true"
                    className="text-[26px] font-normal mr-2 select-none"
                    style={{ color: 'var(--v-dimmed)' }}
                  >
                    #
                  </span>
                  <input
                    ref={titleRef}
                    type="text"
                    value={title}
                    onChange={(e) => {
                      setTitle(e.target.value);
                      setIsTyping(true);
                    }}
                    placeholder="标题"
                    maxLength={200}
                    className="w-full bg-transparent border-0 outline-none text-[26px] font-semibold tracking-tight"
                    style={{ color: 'var(--v-ink)' }}
                  />
                </div>

                <textarea
                  ref={textareaRef}
                  value={content}
                  onChange={(e) => {
                    setContent(e.target.value);
                    setIsTyping(true);
                  }}
                  onKeyDown={handleKeyDown}
                  placeholder="正文..."
                  className="w-full min-h-[360px] resize-none bg-transparent border-0 outline-none text-[16px] leading-[1.9]"
                  style={{ color: 'var(--v-ink)' }}
                />
              </div>

              {splitPreview && (
                <div
                  className="min-w-0 lg:border-l lg:pl-10 pt-2"
                  style={{ borderColor: 'var(--v-border)' }}
                >
                  {title.trim() && (
                    <h1
                      className="text-[26px] font-semibold tracking-tight leading-[1.3] mb-6"
                      style={{ color: 'var(--v-ink)' }}
                    >
                      {title.trim()}
                    </h1>
                  )}
                  <div className="vellum-prose">
                    <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        <CityPickerModal
          open={cityPickerOpen}
          currentCity={city}
          onSelect={setCity}
          onClose={() => setCityPickerOpen(false)}
        />
      </>
    );
  },
);
