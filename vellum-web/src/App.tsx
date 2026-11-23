import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MotionConfig } from 'motion/react';
import type { ReactNode } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from '@/hooks/useAuth';
import { ThemeProvider } from '@/hooks/useTheme';
import { ArticlePage } from '@/pages/ArticlePage';
import { LoginPage } from '@/pages/LoginPage';
import { TimelinePage } from '@/pages/TimelinePage';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

function RequireAuth({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

function RedirectIfAuthed({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth();
  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}

export function App() {
  return (
    <ThemeProvider>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <MotionConfig reducedMotion="user">
            <BrowserRouter>
              <Routes>
                <Route
                  path="/login"
                  element={
                    <RedirectIfAuthed>
                      <LoginPage />
                    </RedirectIfAuthed>
                  }
                />
                <Route
                  path="/"
                  element={
                    <RequireAuth>
                      <TimelinePage />
                    </RequireAuth>
                  }
                />
                <Route
                  path="/articles"
                  element={
                    <RequireAuth>
                      <ArticlePage />
                    </RequireAuth>
                  }
                />
                <Route
                  path="/articles/new"
                  element={
                    <RequireAuth>
                      <ArticlePage />
                    </RequireAuth>
                  }
                />
                <Route
                  path="/articles/:id"
                  element={
                    <RequireAuth>
                      <ArticlePage />
                    </RequireAuth>
                  }
                />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </BrowserRouter>
          </MotionConfig>
        </AuthProvider>
      </QueryClientProvider>
    </ThemeProvider>
  );
}

export default App;
