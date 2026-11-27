import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_app/core/utils/formatters.dart';
import 'package:vellum_app/core/utils/markdown_io.dart';
import 'package:vellum_app/data/models/models.dart';

void main() {
  group('Markdown & formatting utilities', () {
    test('stripDuplicateLeadingHeading removes matching H1/H2 title', () {
      const content = '# 把日子过得慢一点\n\n合上电脑，才发现窗外已经暗了。';
      final cleaned = stripDuplicateLeadingHeading(content, '把日子过得慢一点');
      expect(cleaned, '合上电脑，才发现窗外已经暗了。');
    });

    test('stripDuplicateLeadingHeading preserves non-matching heading', () {
      const content = '# 小标题\n\n正文内容';
      final cleaned = stripDuplicateLeadingHeading(content, '把日子过得慢一点');
      expect(cleaned, '# 小标题\n\n正文内容');
    });

    test('stripMarkdown strips formatting symbols cleanly', () {
      const md = '## 留给自己的小事\n\n- **散步**时，把[手机](https://example.com)放进口袋';
      expect(stripMarkdown(md), '留给自己的小事 散步时，把手机放进口袋');
    });

    test('parseMarkdownOrTextContent extracts leading heading or filename', () {
      final parsedHeading = parseMarkdownOrTextContent(
        'draft.md',
        '# 海边的片刻\n\n下班后绕去海边。',
      );
      expect(parsedHeading.title, '海边的片刻');
      expect(parsedHeading.content, '下班后绕去海边。');

      final parsedPlain = parseMarkdownOrTextContent(
        '随手记.txt',
        '今天风很轻。',
      );
      expect(parsedPlain.title, '随手记');
      expect(parsedPlain.content, '今天风很轻。');
    });

    test('formatters match Figma Chinese editorial format', () {
      final dt = DateTime(2026, 11, 23, 21, 30);
      expect(formatMonthKey(dt), '2026年11月');
      expect(formatWeekday(dt), '周一');
      expect(formatDay(dt), '23');
      expect(formatDetailMeta(dt, '深圳市'), '2026年11月23日 周一 · 21:30 · 深圳市');
      expect(formatDotDate(dt), '2026.11.23');
    });

    test('buildSinglePostExportText handles md and txt formats', () {
      final post = PostItem(
        id: '12345678-abcd',
        type: PostType.article,
        title: '把日子过得慢一点',
        content: '# 把日子过得慢一点\n\n**今天**散步。',
        recordTime: DateTime(2026, 11, 23, 21, 30),
        createdAt: DateTime(2026, 11, 23, 21, 30),
        updatedAt: DateTime(2026, 11, 23, 21, 30),
      );
      expect(buildSinglePostExportText(post, 'md'), '# 把日子过得慢一点\n\n**今天**散步。');
      expect(buildSinglePostExportText(post, 'txt'), '把日子过得慢一点\n\n今天散步。');
    });
  });
}
