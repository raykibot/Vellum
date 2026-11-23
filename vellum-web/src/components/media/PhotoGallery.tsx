import { useState } from 'react';
import { Lightbox } from './Lightbox';

interface PhotoGalleryProps {
  images: string[];
}

export function PhotoGallery({ images }: PhotoGalleryProps) {
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [lightboxIdx, setLightboxIdx] = useState(0);

  if (images.length === 0) return null;

  const openAt = (idx: number) => {
    setLightboxIdx(idx);
    setLightboxOpen(true);
  };

  const tileClass =
    'w-full h-full object-cover transition-transform duration-300 ease-out group-hover:scale-[1.015]';

  return (
    <>
      {images.length === 1 && (
        <div className="mt-5">
          <button
            type="button"
            onClick={() => openAt(0)}
            className="group block w-full aspect-[16/10] rounded-2xl overflow-hidden border cursor-zoom-in"
            style={{ borderColor: 'var(--v-border)' }}
          >
            <img src={images[0]} alt="" className={tileClass} loading="lazy" />
          </button>
        </div>
      )}

      {images.length === 2 && (
        <div className="mt-5 grid grid-cols-2 gap-2.5">
          {images.map((src, idx) => (
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

      {images.length === 3 && (
        <div className="mt-5 space-y-2.5">
          <button
            type="button"
            onClick={() => openAt(0)}
            className="group block w-full aspect-[16/9] rounded-2xl overflow-hidden border cursor-zoom-in"
            style={{ borderColor: 'var(--v-border)' }}
          >
            <img src={images[0]} alt="" className={tileClass} loading="lazy" />
          </button>
          <div className="grid grid-cols-2 gap-2.5">
            {images.slice(1).map((src, idx) => (
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

      {images.length >= 4 && (
        <div className="mt-5 grid grid-cols-3 gap-2">
          {images.map((src, idx) => (
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
        images={images}
        initialIndex={lightboxIdx}
        open={lightboxOpen}
        onClose={() => setLightboxOpen(false)}
      />
    </>
  );
}
