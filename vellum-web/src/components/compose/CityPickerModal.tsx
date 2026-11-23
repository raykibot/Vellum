import { useEffect, useMemo, useState } from 'react';
import { MapPin, Search } from 'lucide-react';
import { searchCities } from '@/lib/chinaCities';
import { Modal } from '@/components/ui/Modal';
import { TactileButton } from '@/components/ui/TactileButton';

interface CityPickerModalProps {
  open: boolean;
  currentCity: string | null;
  onSelect: (city: string | null) => void;
  onClose: () => void;
}

export function CityPickerModal({
  open,
  currentCity,
  onSelect,
  onClose,
}: CityPickerModalProps) {
  const [query, setQuery] = useState('');

  useEffect(() => {
    if (open) {
      setQuery('');
    }
  }, [open]);

  const cities = useMemo(() => searchCities(query), [query]);
  const trimmed = query.trim();
  const hasExact = trimmed.length > 0 && cities.some((c) => c === trimmed);

  const pick = (city: string | null) => {
    onSelect(city);
    onClose();
  };

  return (
    <Modal open={open} onClose={onClose} maxWidthClass="max-w-[360px]" zIndexClass="z-50">
      <div className="p-4">
        <div
          className="flex items-center gap-2 px-3 h-9 rounded-xl border"
          style={{
            backgroundColor: 'var(--v-rail)',
            borderColor: 'var(--v-border)',
          }}
        >
          <Search className="w-4 h-4 shrink-0" style={{ color: 'var(--v-muted)' }} />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="城市"
            autoFocus
            className="w-full bg-transparent text-[13.5px] outline-none"
            style={{ color: 'var(--v-ink)' }}
          />
        </div>

        <div className="mt-3 max-h-[240px] overflow-y-auto subtle-scroll space-y-0.5">
          {trimmed && !hasExact && (
            <button
              type="button"
              onClick={() => pick(trimmed)}
              className="w-full text-left px-3 py-2 rounded-lg flex items-center gap-2 text-[13.5px] hover:bg-[var(--v-hover)] cursor-pointer transition-colors"
              style={{ color: 'var(--v-ink)' }}
            >
              <MapPin className="w-3.5 h-3.5 shrink-0" style={{ color: 'var(--v-muted)' }} />
              <span>{trimmed}</span>
            </button>
          )}

          {cities.map((city) => {
            const active = city === currentCity;
            return (
              <button
                key={city}
                type="button"
                onClick={() => pick(city)}
                className="w-full text-left px-3 py-2 rounded-lg flex items-center justify-between text-[13.5px] hover:bg-[var(--v-hover)] cursor-pointer transition-colors"
                style={{
                  color: 'var(--v-ink)',
                  backgroundColor: active ? 'var(--v-hover)' : undefined,
                  fontWeight: active ? 600 : 400,
                }}
              >
                <span>{city}</span>
              </button>
            );
          })}
        </div>

        <div
          className="mt-3 pt-3 border-t flex items-center justify-between"
          style={{ borderColor: 'var(--v-border)' }}
        >
          <TactileButton variant="ghost" size="sm" onClick={() => pick(null)}>
            留空
          </TactileButton>
          <TactileButton variant="ghost" size="sm" onClick={onClose}>
            取消
          </TactileButton>
        </div>
      </div>
    </Modal>
  );
}
