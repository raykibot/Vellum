import { clsx, type ClassValue } from 'clsx';
import dayjs from 'dayjs';
import { twMerge } from 'tailwind-merge';

const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'] as const;

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

export function stripMarkdown(md: string): string {
  return md
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, '')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^>\s?/gm, '')
    .replace(/^[-*+]\s+/gm, '')
    .replace(/^\d+\.\s+/gm, '')
    .replace(/[`*_~]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function markdownToPlainText(md: string): string {
  return md
    .replace(/```[^\n]*\n([\s\S]*?)```/g, '$1')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, '')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^>\s?/gm, '')
    .replace(/[`*_~]/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export function stripDuplicateLeadingHeading(content: string, title: string | null): string {
  if (!title) return content;
  const trimmedTitle = title.trim();
  if (!trimmedTitle) return content;

  const lines = content.replace(/\r\n/g, '\n').split('\n');
  let firstIdx = 0;
  while (firstIdx < lines.length && lines[firstIdx].trim() === '') {
    firstIdx += 1;
  }
  if (firstIdx >= lines.length) return content;

  const match = lines[firstIdx].trim().match(/^#{1,3}\s+(.+)$/);
  if (match && match[1].trim() === trimmedTitle) {
    let nextIdx = firstIdx + 1;
    while (nextIdx < lines.length && lines[nextIdx].trim() === '') {
      nextIdx += 1;
    }
    return lines.slice(nextIdx).join('\n');
  }
  return content;
}

export function formatMonthKey(iso: string): string {
  return dayjs(iso).format('YYYY年M月');
}

export function formatWeekday(iso: string): string {
  return WEEKDAYS[dayjs(iso).day()] ?? '';
}

export function formatDay(iso: string): string {
  return dayjs(iso).format('D');
}

export function formatTime(iso: string): string {
  return dayjs(iso).format('HH:mm');
}

export function formatFullDate(iso: string): string {
  return `${dayjs(iso).format('YYYY年M月D日')} ${formatWeekday(iso)}`;
}

export function formatShortDate(iso: string): string {
  return dayjs(iso).format('MM/DD');
}

export function formatDatetimeLabel(iso: string): string {
  const target = dayjs(iso);
  const now = dayjs();
  if (target.isSame(now, 'day')) {
    return `今天 ${target.format('HH:mm')}`;
  }
  if (target.isSame(now, 'year')) {
    return target.format('M月D日 HH:mm');
  }
  return target.format('YYYY年M月D日 HH:mm');
}

export function toLocalInputValue(iso: string): string {
  return dayjs(iso).format('YYYY-MM-DDTHH:mm');
}

export function fromLocalInputValue(localStr: string): string {
  return dayjs(localStr).toISOString();
}
