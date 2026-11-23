import { useState, type FormEvent } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { Moon, Server, Sun } from 'lucide-react';
import { getApiBaseUrl, setApiBaseUrl } from '@/lib/storage';
import { useAuth } from '@/hooks/useAuth';
import { useTheme } from '@/hooks/useTheme';
import { TactileButton } from '@/components/ui/TactileButton';

export function LoginPage() {
  const { login } = useAuth();
  const { resolvedTheme, toggleQuick } = useTheme();

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [serverOpen, setServerOpen] = useState(() => Boolean(getApiBaseUrl()));
  const [serverUrl, setServerUrl] = useState(() => getApiBaseUrl());
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    const trimmedUser = username.trim();
    if (!trimmedUser || !password) {
      setErrorMsg('请输入账号与密码');
      return;
    }

    setErrorMsg(null);
    setSubmitting(true);
    try {
      setApiBaseUrl(serverUrl);
      await login({ username: trimmedUser, password });
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : '登录失败');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      className="min-h-screen w-full flex flex-col items-center justify-center p-6 relative select-none transition-colors duration-200"
      style={{ backgroundColor: 'var(--v-canvas)', color: 'var(--v-ink)' }}
    >
      <div className="fixed top-4 right-4">
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
      </div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.28, ease: [0.22, 1, 0.36, 1] }}
        className="w-full max-w-[310px]"
      >
        <div className="flex items-center justify-between mb-7">
          <h1 className="text-[26px] font-semibold tracking-tight">Vellum</h1>
          <TactileButton
            variant="ghost"
            size="icon"
            aria-label="配置服务地址"
            onClick={() => setServerOpen((v) => !v)}
            style={serverOpen ? { backgroundColor: 'var(--v-hover)', color: 'var(--v-ink)' } : undefined}
          >
            <Server className="w-4 h-4" strokeWidth={1.8} />
          </TactileButton>
        </div>

        <form onSubmit={handleSubmit} className="space-y-3">
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="账号"
            autoComplete="username"
            autoFocus
            className="w-full h-11 px-3.5 rounded-xl border text-[14px] outline-none transition-colors focus:border-[var(--v-ink)]"
            style={{
              backgroundColor: 'var(--v-rail)',
              borderColor: 'var(--v-border)',
              color: 'var(--v-ink)',
            }}
          />

          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="密码"
            autoComplete="current-password"
            className="w-full h-11 px-3.5 rounded-xl border text-[14px] outline-none transition-colors focus:border-[var(--v-ink)]"
            style={{
              backgroundColor: 'var(--v-rail)',
              borderColor: 'var(--v-border)',
              color: 'var(--v-ink)',
            }}
          />

          <AnimatePresence initial={false}>
            {serverOpen && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
                className="overflow-hidden"
              >
                <input
                  type="url"
                  value={serverUrl}
                  onChange={(e) => setServerUrl(e.target.value)}
                  placeholder="http://localhost:8080"
                  className="w-full h-11 px-3.5 rounded-xl border text-[13.5px] outline-none transition-colors focus:border-[var(--v-ink)]"
                  style={{
                    backgroundColor: 'var(--v-rail)',
                    borderColor: 'var(--v-border)',
                    color: 'var(--v-ink)',
                  }}
                />
              </motion.div>
            )}
          </AnimatePresence>

          {errorMsg && (
            <div className="text-[12.5px] text-[#dc2626] pt-0.5 text-center">{errorMsg}</div>
          )}

          <TactileButton
            type="submit"
            variant="solid"
            loading={submitting}
            className="w-full h-11 rounded-xl text-[14px] mt-1"
          >
            进入
          </TactileButton>
        </form>
      </motion.div>
    </div>
  );
}
