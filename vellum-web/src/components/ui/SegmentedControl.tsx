import { motion } from 'motion/react';
import { cn } from '@/lib/utils';

export interface SegmentedOption<T extends string> {
  value: T;
  label: string;
}

interface SegmentedControlProps<T extends string> {
  options: readonly SegmentedOption<T>[];
  value: T;
  onChange: (value: T) => void;
  layoutId?: string;
  size?: 'sm' | 'md';
  className?: string;
}

export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  layoutId = 'vellum-segment-thumb',
  size = 'md',
  className,
}: SegmentedControlProps<T>) {
  const buttonSizeClass = size === 'sm' ? 'px-3 py-1 text-[12px]' : 'px-4 py-1 text-[12.5px]';

  return (
    <div
      role="tablist"
      className={cn('relative inline-grid p-[3px] rounded-full select-none', className)}
      style={{
        backgroundColor: 'var(--v-track)',
        gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))`,
      }}
    >
      {options.map((option) => {
        const active = option.value === value;
        return (
          <button
            key={option.value}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onChange(option.value)}
            className={cn(
              'relative z-10 font-medium rounded-full cursor-pointer transition-colors duration-150',
              buttonSizeClass,
            )}
            style={{ color: active ? 'var(--v-ink)' : 'var(--v-muted)' }}
          >
            {active && (
              <motion.span
                layoutId={layoutId}
                transition={{ type: 'spring', stiffness: 440, damping: 34 }}
                className="absolute inset-0 rounded-full -z-10"
                style={{
                  backgroundColor: 'var(--v-selected)',
                  boxShadow: 'var(--v-selected-shadow)',
                }}
              />
            )}
            {option.label}
          </button>
        );
      })}
    </div>
  );
}
