import type { ReactNode } from 'react';
import { motion, type HTMLMotionProps } from 'motion/react';
import { cn } from '@/lib/utils';

type ButtonVariant = 'solid' | 'ghost' | 'soft' | 'danger';
type ButtonSize = 'sm' | 'md' | 'icon';

export interface TactileButtonProps extends Omit<HTMLMotionProps<'button'>, 'children'> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
  children: ReactNode;
}

export function TactileButton({
  variant = 'solid',
  size = 'md',
  loading = false,
  disabled,
  className,
  style,
  children,
  type = 'button',
  ...rest
}: TactileButtonProps) {
  const isDisabled = Boolean(disabled || loading);

  const sizeClass =
    size === 'icon'
      ? 'w-8 h-8 rounded-[9px]'
      : size === 'sm'
        ? 'h-8 px-3.5 rounded-[9px] text-[12.5px]'
        : 'h-9 px-4 rounded-[10px] text-[13px]';

  const variantClass =
    variant === 'solid'
      ? 'font-medium hover:opacity-90'
      : variant === 'ghost'
        ? 'font-medium text-[var(--v-muted)] hover:text-[var(--v-ink)] hover:bg-[var(--v-hover)]'
        : variant === 'soft'
          ? 'font-medium bg-[var(--v-track)] text-[var(--v-ink)] hover:opacity-85'
          : 'font-medium bg-[#dc2626] text-white hover:bg-[#b91c1c]';

  const variantStyle =
    variant === 'solid'
      ? {
          backgroundColor: 'var(--v-action-bg)',
          color: 'var(--v-action-text)',
          boxShadow: 'var(--v-action-shadow)',
          ...style,
        }
      : style;

  return (
    <motion.button
      type={type}
      disabled={isDisabled}
      whileTap={isDisabled ? undefined : { scale: 0.96 }}
      transition={{ type: 'spring', stiffness: 520, damping: 32 }}
      className={cn(
        'inline-flex items-center justify-center shrink-0 select-none transition-colors duration-150 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed',
        sizeClass,
        variantClass,
        className,
      )}
      style={variantStyle}
      {...rest}
    >
      <span
        aria-hidden="true"
        className="inline-flex items-center overflow-hidden transition-all duration-200"
        style={{
          width: loading ? 13 : 0,
          marginRight: loading ? 6 : 0,
          opacity: loading ? 1 : 0,
          transform: loading ? 'scale(1)' : 'scale(0.6)',
          transitionTimingFunction: 'cubic-bezier(0.22, 1, 0.36, 1)',
        }}
      >
        <span className="w-3 h-3 rounded-full border-[1.75px] border-current border-r-transparent animate-spin" />
      </span>
      {children}
    </motion.button>
  );
}
