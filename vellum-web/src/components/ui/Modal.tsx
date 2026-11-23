import { useEffect, type ReactNode } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { cn } from '@/lib/utils';

interface ModalProps {
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  maxWidthClass?: string;
  zIndexClass?: string;
}

export function Modal({
  open,
  onClose,
  children,
  maxWidthClass = 'max-w-[500px]',
  zIndexClass = 'z-40',
}: ModalProps) {
  useEffect(() => {
    if (!open) return;
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [open, onClose]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.18 }}
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              onClose();
            }
          }}
          className={cn(
            'fixed inset-0 flex items-center justify-center p-4 bg-black/28 backdrop-blur-md',
            zIndexClass,
          )}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.96, y: 8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 6 }}
            transition={{ type: 'spring', stiffness: 420, damping: 32 }}
            className={cn('w-full rounded-2xl border overflow-hidden', maxWidthClass)}
            style={{
              backgroundColor: 'var(--v-canvas)',
              borderColor: 'var(--v-border)',
              boxShadow: '0 24px 48px rgba(0, 0, 0, 0.18)',
            }}
          >
            {children}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
