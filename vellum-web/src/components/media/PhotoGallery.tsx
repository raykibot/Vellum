import { useMemo, useState } from 'react';
import { resolveMediaUrl } from '@/lib/storage';
import { cn } from '@/lib/utils';
import { Lightbox } from './Lightbox';

interface PhotoGalleryProps {
  images: string[];
  className?: string;
}

export function PhotoGallery({ images, className = 'mt-5' }: PhotoGalleryProps) {
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [lightboxIdx, setLightboxIdx] = useState(0);

  const resolvedImages = useMemo(() => images.map(resolveMediaUrl), [images]);

  if (resolvedImages.length === 0) return null;

  const openAt = (idx: number) => {
    setLightboxIdx(idx);
    setLightboxOpen(true);
  };

  const tileClass =
    'w-full h-full object-cover transition-transform duration-300 ease-out group-hover:scale-[1.015]';

  return (
    <>
      {resolvedImages.length === 1 && (
        <div className={className}>
          <button
            type="button"
            onClick={() => openAt(0)}
            className="group block w-full aspect-[16/10] rounded-2xl overflow-hidden border cursor-zoom-in"
            style={{ borderColor: 'var(--v-border)' }}
          >
            <img src={resolvedImages[0]} alt="" className={tileClass} loading="lazy" />
          </button>
        </div>
      )}

      {resolvedImages.length === 2 && (
        <div className={cn('grid grid-cols-2 gap-2.5', className)}>
          {resolvedImages.map((src, idx) => (
            <button
              key={src + idx}
              type="button"
              onClick={() => openAt(idx)}
              className="group block w-full aspect-[4/3] rounded-2xl overflow-hidden border cursor-zoom-in"
              style={{ borderColor: 'var(--v-border)' }}
            >
              <img src={src} alt="" className={tileClass} loading="lazy" />
            </button>
          ))}
        </div>
      )}

      {resolvedImages.length === 3 && (
        <div className={cn('space-y-2.5', className)}>
          <button
            type="button"
            onClick={() => openAt(0)}
            className="group block w-full aspect-[16/9] rounded-2xl overflow-hidden border cursor-zoom-in"
            style={{ borderColor: 'var(--v-border)' }}
          >
            <img src={resolvedImages[0]} alt="" className={tileClass} loading="lazy" />
          </button>
          <div className="grid grid-cols-2 gap-2.5">
            {resolvedImages.slice(1).map((src, idx) => (
              <button
                key={src + idx}
                type="button"
                onClick={() => openAt(idx + 1)}
                className="group block w-full aspect-[4/3] rounded-2xl overflow-hidden border cursor-zoom-in"
                style={{ borderColor: 'var(--v-border)' }}
              >
                <img src={src} alt="" className={tileClass} loading="lazy" />
              </button>
            ))}
          </div>
        </div>
      )}

      {resolvedImages.length >= 4 && (
        <div className={cn('grid grid-cols-3 gap-2', className)}>
          {resolvedImages.map((src, idx) => (
            <button
              key={src + idx}
              type="button"
              onClick={() => openAt(idx)}
              className="group block w-full aspect-square rounded-xl overflow-hidden border cursor-zoom-in"
              style={{ borderColor: 'var(--v-border)' }}
            >
              <img src={src} alt="" className={tileClass} loading="lazy" />
            </button>
          ))}
        </div>
      )}

      <Lightbox
        images={resolvedImages}
        initialIndex={lightboxIdx}
        open={lightboxOpen}
        onClose={() => setLightboxOpen(false)}
      />
    </>
  );
}
