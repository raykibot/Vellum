const TOKEN_KEY = 'vellum_token';
const EXPIRES_AT_KEY = 'vellum_token_expires_at';
const API_BASE_KEY = 'vellum_api_base';
const THEME_KEY = 'vellum_theme';

export type ThemeMode = 'light' | 'dark' | 'system';

export function normalizeApiBase(raw: string): string {
  return raw.trim().replace(/\/+$/, '');
}

export function getApiBaseUrl(): string {
  try {
    return normalizeApiBase(localStorage.getItem(API_BASE_KEY) || '');
  } catch {
    return '';
  }
}

export function setApiBaseUrl(url: string): void {
  const normalized = normalizeApiBase(url);
  if (!normalized) {
    localStorage.removeItem(API_BASE_KEY);
  } else {
    localStorage.setItem(API_BASE_KEY, normalized);
  }
}

export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setAuthSession(token: string, expiresAt: string): void {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(EXPIRES_AT_KEY, expiresAt);
}

export function clearAuthSession(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(EXPIRES_AT_KEY);
}

export function isTokenValid(): boolean {
  const token = getToken();
  if (!token) return false;
  const expiresAt = localStorage.getItem(EXPIRES_AT_KEY);
  if (!expiresAt) return true;
  const expiresMs = Date.parse(expiresAt);
  if (Number.isNaN(expiresMs)) return true;
  return expiresMs > Date.now();
}

export function getStoredTheme(): ThemeMode {
  try {
    const raw = localStorage.getItem(THEME_KEY);
    if (raw === 'light' || raw === 'dark' || raw === 'system') {
      return raw;
    }
  } catch {
    // ignore storage failures
  }
  return 'system';
}

export function setStoredTheme(mode: ThemeMode): void {
  localStorage.setItem(THEME_KEY, mode);
}
