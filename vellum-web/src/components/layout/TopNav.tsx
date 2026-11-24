import { Moon, PanelLeft, Settings, Sun } from 'lucide-react';
import { useTheme } from '@/hooks/useTheme';
import { TactileButton } from '@/components/ui/TactileButton';

interface TopNavProps {
  sidebarOpen: boolean;
  onToggleSidebar: () => void;
  composingArticle: boolean;
  articleSubmitting?: boolean;
  onWriteMoment: () => void;
  onWriteArticle: () => void;
  onCancelArticle: () => void;
  onPublishArticle: () => void;
  onBrandClick: () => void;
  onOpenSettings: () => void;
}

export function TopNav({
  sidebarOpen,
  onToggleSidebar,
  composingArticle,
  articleSubmitting = false,
  onWriteMoment,
  onWriteArticle,
  onCancelArticle,
  onPublishArticle,
  onBrandClick,
  onOpenSettings,
}: TopNavProps) {
  const { resolvedTheme, toggleQuick } = useTheme();

  return (
    <header
      className="h-[52px] shrink-0 px-4 md:px-5 flex items-center justify-between border-b relative z-30 backdrop-blur-xl transition-colors duration-200"
      style={{
        backgroundColor: 'var(--v-header)',
        borderColor: 'var(--v-border)',
      }}
    >
      {/* Left: persistent sidebar toggle + Vellum wordmark */}
      <div className="flex items-center gap-1.5 min-w-0">
        <TactileButton
          variant="ghost"
          size="icon"
          aria-label={sidebarOpen ? '收起侧边栏' : '展开侧边栏'}
          title="展开/收起侧边栏 (Ctrl+\)"
          onClick={onToggleSidebar}
          className="hidden md:inline-flex"
          style={
            sidebarOpen
              ? { backgroundColor: 'var(--v-hover)', color: 'var(--v-ink)' }
              : undefined
          }
        >
          <PanelLeft className="w-[17px] h-[17px]" strokeWidth={1.8} />
        </TactileButton>

        <button
          type="button"
          onClick={onBrandClick}
          className="text-[15px] font-semibold tracking-tight px-1.5 py-1 rounded-lg cursor-pointer transition-opacity hover:opacity-80"
          style={{ color: 'var(--v-ink)' }}
        >
          Vellum
        </button>
      </div>

      {/* Right: theme toggle, settings, compose actions */}
      <div className="flex items-center gap-1.5">
        <TactileButton
          variant="ghost"
          size="icon"
          aria-label="切换浅色或深色模式"
          onClick={toggleQuick}
        >
          {resolvedTheme === 'dark' ? (
            <Sun className="w-4 h-4" strokeWidth={1.8} />
          ) : (
            <Moon className="w-4 h-4" strokeWidth={1.8} />
          )}
        </TactileButton>

        <TactileButton
          variant="ghost"
          size="icon"
          aria-label="设置"
          onClick={onOpenSettings}
        >
          <Settings className="w-4 h-4" strokeWidth={1.8} />
        </TactileButton>

        {composingArticle ? (
          <>
            <TactileButton variant="ghost" size="sm" onClick={onCancelArticle} className="ml-1">
              取消
            </TactileButton>
            <TactileButton
              variant="solid"
              size="sm"
              loading={articleSubmitting}
              onClick={onPublishArticle}
            >
              发布
            </TactileButton>
          </>
        ) : (
          <>
            <TactileButton variant="ghost" size="sm" onClick={onWriteArticle} className="ml-1">
              写长文
            </TactileButton>
            <TactileButton variant="solid" size="sm" onClick={onWriteMoment}>
              写一条
            </TactileButton>
          </>
        )}
      </div>
    </header>
  );
}
