import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { loginRequest } from '@/api/auth';
import { onUnauthorized } from '@/api/client';
import { clearAuthSession, isTokenValid, setAuthSession } from '@/lib/storage';
import type { LoginRequest } from '@/types/api';

interface AuthContextValue {
  isAuthenticated: boolean;
  login: (payload: LoginRequest) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => isTokenValid());

  const logout = useCallback(() => {
    clearAuthSession();
    queryClient.clear();
    setIsAuthenticated(false);
  }, [queryClient]);

  useEffect(() => {
    return onUnauthorized(() => {
      queryClient.clear();
      setIsAuthenticated(false);
    });
  }, [queryClient]);

  const login = useCallback(async (payload: LoginRequest) => {
    const res = await loginRequest(payload);
    setAuthSession(res.token, res.expiresAt);
    setIsAuthenticated(true);
  }, []);

  return (
    <AuthContext.Provider value={{ isAuthenticated, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return ctx;
}
