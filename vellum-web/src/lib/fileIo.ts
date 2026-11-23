import type { PostItem } from '@/types/api';
import { markdownToPlainText, stripDuplicateLeadingHeading } from './utils';

export async function parseMarkdownOrTextFile(
  file: File,
): Promise<{ title: string; content: string }> {
  const raw = (await file.text()).replace(/\r\n/g, '\n');
  const lines = raw.split('\n');

  let firstNonEmpty = 0;
  while (firstNonEmpty < lines.length && lines[firstNonEmpty].trim() === '') {
    firstNonEmpty += 1;
  }

  const fallbackTitle = file.name.replace(/\.(md|markdown|txt)$/i, '').trim();
  if (firstNonEmpty < lines.length) {
    const headingMatch = lines[firstNonEmpty].trim().match(/^#{1,2}\s+(.+)$/);
    if (headingMatch) {
      let bodyStart = firstNonEmpty + 1;
      while (bodyStart < lines.length && lines[bodyStart].trim() === '') {
        bodyStart += 1;
      }
      const body = lines.slice(bodyStart).join('\n').trim();
      return {
        title: headingMatch[1].trim(),
        content: body || raw.trim(),
      };
    }
  }

  return {
    title: fallbackTitle,
    content: raw.trim(),
  };
}

export function downloadPostFile(post: PostItem, ext: 'md' | 'txt'): void {
  const cleanBody = stripDuplicateLeadingHeading(post.content, post.title);
  let output: string;

  if (ext === 'md') {
    output = post.title ? `# ${post.title}\n\n${cleanBody}` : post.content;
  } else {
    const plainBody = markdownToPlainText(cleanBody);
    output = post.title ? `${post.title}\n\n${plainBody}` : plainBody;
  }

  const baseName = (post.title || `vellum-${post.id.slice(0, 8)}`).replace(/[\\/:*?"<>|]/g, '-');
  const blob = new Blob([output], {
    type: ext === 'md' ? 'text/markdown;charset=utf-8' : 'text/plain;charset=utf-8',
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `${baseName}.${ext}`;
  anchor.click();
  URL.revokeObjectURL(url);
}
