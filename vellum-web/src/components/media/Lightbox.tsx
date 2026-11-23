import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { ChevronLeft, ChevronRight, X, ZoomIn, ZoomOut } from 'lucide-react';

interface LightboxProps {
  images: string[];
  initialIndex: number;
  open: boolean;
  onClose: () => void;
}

export function Lightbox({ images, initialIndex, open, onClose }: LightboxProps) {
  const [index, setIndex] = useState(initialIndex);
  const [zoomed, setZoomed] = useState(false);

  useEffect(() => {
    if (open) {
      setIndex(initialIndex);
      setZoomed(false);
    }
  }, [open, initialIndex]);

  useEffect(() => {
    if (!open || images.length === 0) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      } else if (event.key === 'ArrowLeft' && images.length > 1) {
        setZoomed(false);
        setIndex((prev) => (prev - 1 + images.length) % images.length);
      } else if (event.key === 'ArrowRight' && images.length > 1) {
        setZoomed(false);
        setIndex((prev) => (prev + 1) % images.length);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [open, images.length, onClose]);

  const currentUrl = images[index];
  const hasMulti = images.length > 1;

  return (
    <AnimatePresence>
      {open && currentUrl && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              onClose();
            }
          }}
          className="fixed inset-0 z-50 flex items-center justify-center p-6 md:p-10 bg-[#0a0a0c]/84 backdrop-blur-2xl"
        >
          <div className="fixed top-5 right-5 flex items-center gap-2 z-10">
            <button
              type="button"
              aria-label={zoomed ? '还原' : '放大'}
              onClick={() => setZoomed((z) => !z)}
              className="w-9 h-9 rounded-full flex items-center justify-center bg-white/10 text-white/80 hover:text-white hover:bg-white/16 transition-colors cursor-pointer"
            >
              {zoomed ? <ZoomOut className="w-4 h-4" /> : <ZoomIn className="w-4 h-4" />}
            </button>
            <button
              type="button"
              aria-label="关闭"
              onClick={onClose}
              className="w-9 h-9 rounded-full flex items-center justify-center bg-white/10 text-white/80 hover:text-white hover:bg-white/16 transition-colors cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>

          {hasMulti && (
            <>
              <button
                type="button"
                aria-label="上一张"
                onClick={() => {
                  setZoomed(false);
                  setIndex((prev) => (prev - 1 + images.length) % images.length);
                }}
                className="fixed left-4 md:left-6 w-10 h-10 rounded-full flex items-center justify-center bg-white/10 text-white/80 hover:text-white hover:bg-white/16 transition-colors cursor-pointer z-10"
              >
                <ChevronLeft className="w-5 h-5" />
              </button>
              <button
                type="button"
                aria-label="下一张"
                onClick={() => {
                  setZoomed(false);
                  setIndex((prev) => (prev + 1) % images.length);
                }}
                className="fixed right-4 md:right-6 w-10 h-10 rounded-full flex items-center justify-center bg-white/10 text-white/80 hover:text-white hover:bg-white/16 transition-colors cursor-pointer z-10"
              >
                <ChevronRight className="w-5 h-5" />
              </button>
            </>
          )}

          <motion.img
            key={currentUrl}
            src={currentUrl}
            alt=""
            initial={{ opacity: 0, scale: 0.96 }}
            animate={{ opacity: 1, scale: zoomed ? 1.45 : 1 }}
            exit={{ opacity: 0, scale: 0.96 }}
            transition={{ type: 'spring', stiffness: 380, damping: 32 }}
            onClick={() => setZoomed((z) => !z)}
            className="max-w-full max-h-[85vh] rounded-2xl object-contain shadow-2xl select-none cursor-zoom-in"
            style={{ cursor: zoomed ? 'zoom-out' : 'zoom-in' }}
          />
        </motion.div>
      )}
    </AnimatePresence>
  );
}
