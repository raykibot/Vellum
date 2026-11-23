import { useEffect, useState } from 'react';
import { Check, X } from 'lucide-react';
import { getApiBaseUrl, setApiBaseUrl, type ThemeMode } from '@/lib/storage';
import { cn } from '@/lib/utils';
import { useAuth } from '@/hooks/useAuth';
import { useTheme } from '@/hooks/useTheme';
import { Modal } from '@/components/ui/Modal';
import { TactileButton } from '@/components/ui/TactileButton';

interface SettingsModalProps {
  open: boolean;
  onClose: () => void;
}

const THEME_OPTIONS: readonly { value: ThemeMode; label: string }[] = [
  { value: 'light', label: '浅色' },
  { value: 'dark', label: '深色' },
  { value: 'system', label: '跟随系统' },
];

export function SettingsModal({ open, onClose }: SettingsModalProps) {
  const { mode, setMode } = useTheme();
  const { logout } = useAuth();
  const [serverUrl, setServerUrl] = useState('');
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (open) {
      setServerUrl(getApiBaseUrl());
      setSaved(false);
    }
  }, [open]);

  const handleSaveServer = () => {
    setApiBaseUrl(serverUrl);
    setSaved(true);
    setTimeout(() => setSaved(false), 1200);
  };

  return (
    <Modal open={open} onClose={onClose} maxWidthClass="max-w-[440px]">
      <div className="p-5 space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-[16px] font-semibold tracking-tight" style={{ color: 'var(--v-ink)' }}>
            设置
          </h2>
          <TactileButton variant="ghost" size="icon" aria-label="关闭" onClick={onClose}>
            <X className="w-4 h-4" />
          </TactileButton>
        </div>

        {/* Appearance */}
        <div>
          <div className="text-[12.5px] font-medium mb-2.5" style={{ color: 'var(--v-muted)' }}>
            外观
          </div>
          <div className="grid grid-cols-3 gap-2.5">
            {THEME_OPTIONS.map((item) => {
              const active = mode === item.value;
              return (
                <button
                  key={item.value}
                  type="button"
                  onClick={() => setMode(item.value)}
                  className={cn(
                    'rounded-xl p-2 text-left border transition-all cursor-pointer active:scale-[0.98]',
                  )}
                  style={{
                    backgroundColor: 'var(--v-rail)',
                    borderColor: active ? 'var(--v-ink)' : 'var(--v-border)',
                    boxShadow: active ? '0 0 0 1px var(--v-ink)' : 'none',
                  }}
                >
                  {/* Visual mini window preview */}
                  <div className="h-11 rounded-lg overflow-hidden border flex" style={{ borderColor: 'var(--v-border)' }}>
                    {item.value === 'light' && (
                      <>
                        <div className="w-1/3 h-full bg-[#F5F5F7] border-r border-black/5" />
                        <div className="w-2/3 h-full bg-white" />
                      </>
                    )}
                    {item.value === 'dark' && (
                      <>
                        <div className="w-1/3 h-full bg-[#111113] border-r border-white/10" />
                        <div className="w-2/3 h-full bg-[#0B0B0C]" />
                      </>
                    )}
                    {item.value === 'system' && (
                      <>
                        <div className="w-1/2 h-full bg-white" />
                        <div className="w-1/2 h-full bg-[#0B0B0C]" />
                      </>
                    )}
                  </div>
                  <div
                    className="mt-2 text-[12px] font-medium text-center"
                    style={{ color: active ? 'var(--v-ink)' : 'var(--v-muted)' }}
                  >
                    {item.label}
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Server address */}
        <div>
          <div className="text-[12.5px] font-medium mb-2" style={{ color: 'var(--v-muted)' }}>
            服务地址
          </div>
          <div className="flex items-center gap-2">
            <input
              type="url"
              value={serverUrl}
              onChange={(e) => setServerUrl(e.target.value)}
              placeholder="http://localhost:8080"
              className="flex-1 h-9 px-3 rounded-[10px] border text-[13px] outline-none"
              style={{
                backgroundColor: 'var(--v-rail)',
                borderColor: 'var(--v-border)',
                color: 'var(--v-ink)',
              }}
            />
            <TactileButton variant="soft" size="sm" className="h-9" onClick={handleSaveServer}>
              {saved ? <Check className="w-4 h-4" /> : '保存'}
            </TactileButton>
          </div>
        </div>

        {/* Account */}
        <div
          className="pt-4 border-t flex items-center justify-end"
          style={{ borderColor: 'var(--v-border)' }}
        >
          <TactileButton
            variant="danger"
            size="sm"
            onClick={() => {
              onClose();
              logout();
            }}
          >
            退出登录
          </TactileButton>
        </div>
      </div>
    </Modal>
  );
}
