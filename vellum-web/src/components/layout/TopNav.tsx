import { Moon, PanelLeft, Settings, Sun } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useTheme } from '@/hooks/useTheme';
import { SegmentedControl } from '@/components/ui/SegmentedControl';
import { TactileButton } from '@/components/ui/TactileButton';

export type NavTab = 'moment' | 'article';

interface TopNavProps {
  activeTab: NavTab;
  showSidebarToggle?: boolean;
  sidebarOpen?: boolean;
  onToggleSidebar?: () => void;
  primaryActionLabel: string;
  primaryActionLoading?: boolean;
  primaryActionDisabled?: boolean;
  onPrimaryAction: () => void;
  onOpenSettings: () => void;
}

const TAB_OPTIONS = [
  { value: 'moment', label: '动态' },
  { value: 'article', label: '长文' },
] as const;

export function TopNav({
  activeTab,
  showSidebarToggle = false,
  sidebarOpen = false,
  onToggleSidebar,
  primaryActionLabel,
  primaryActionLoading = false,
  primaryActionDisabled = false,
  onPrimaryAction,
  onOpenSettings,
}: TopNavProps) {
  const navigate = useNavigate();
  const { resolvedTheme, toggleQuick } = useTheme();

  const handleTabChange = (nextTab: NavTab) => {
    if (nextTab === 'moment') {
      navigate('/');
    } else {
      navigate('/articles');
    }
  };

  return (
    <header
      className="h-[52px] shrink-0 px-4 md:px-5 flex items-center justify-between border-b relative z-30 backdrop-blur-xl transition-colors duration-200"
      style={{
        backgroundColor: 'var(--v-header)',
        borderColor: 'var(--v-border)',
      }}
    >
      {/* Left: optional drawer toggle + Vellum wordmark */}
      <div className="flex items-center gap-1.5 min-w-0">
        {showSidebarToggle && (
          <TactileButton
            variant="ghost"
            size="icon"
            aria-label="切换长文列表"
            onClick={onToggleSidebar}
            style={
              sidebarOpen
                ? { backgroundColor: 'var(--v-hover)', color: 'var(--v-ink)' }
                : undefined
            }
          >
            <PanelLeft className="w-[17px] h-[17px]" strokeWidth={1.8} />
          </TactileButton>
        )}
        <Link
          to="/"
          className="text-[15px] font-semibold tracking-tight px-1.5 py-1 rounded-lg transition-opacity hover:opacity-80"
          style={{ color: 'var(--v-ink)' }}
        >
          Vellum
        </Link>
      </div>

      {/* Center: 动态 / 长文 segmented control */}
      <div className="absolute left-1/2 -translate-x-1/2">
        <SegmentedControl options={TAB_OPTIONS} value={activeTab} onChange={handleTabChange} />
      </div>

      {/* Right: theme toggle, settings, primary action */}
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

        <TactileButton
          variant="solid"
          size="sm"
          loading={primaryActionLoading}
          disabled={primaryActionDisabled}
          onClick={onPrimaryAction}
          className="ml-1"
        >
          {primaryActionLabel}
        </TactileButton>
      </div>
    </header>
  );
}
