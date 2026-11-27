import 'package:vellum_app/core/utils/formatters.dart';
import 'package:vellum_app/data/models/models.dart';

String stripMarkdown(String md) {
  return md
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
      .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
      .replaceAll(RegExp(r'[`*_~]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String markdownToPlainText(String md) {
  return md
      .replaceAllMapped(RegExp(r'```[^\n]*\n([\s\S]*?)```'), (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
      .replaceAll(RegExp(r'[`*_~]'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String stripDuplicateLeadingHeading(String content, String? title) {
  if (title == null || title.trim().isEmpty) return content;
  final trimmedTitle = title.trim();
  final lines = content.replaceAll('\r\n', '\n').split('\n');

  var firstIdx = 0;
  while (firstIdx < lines.length && lines[firstIdx].trim().isEmpty) {
    firstIdx++;
  }
  if (firstIdx >= lines.length) return content;

  final match = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(lines[firstIdx].trim());
  if (match != null && match.group(1)!.trim() == trimmedTitle) {
    var nextIdx = firstIdx + 1;
    while (nextIdx < lines.length && lines[nextIdx].trim().isEmpty) {
      nextIdx++;
    }
    return lines.sublist(nextIdx).join('\n');
  }
  return content;
}

({String title, String content}) parseMarkdownOrTextContent(
  String filename,
  String rawText,
) {
  final normalized = rawText.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');

  var firstNonEmpty = 0;
  while (firstNonEmpty < lines.length && lines[firstNonEmpty].trim().isEmpty) {
    firstNonEmpty++;
  }

  final fallbackTitle =
      filename.replaceAll(RegExp(r'\.(md|markdown|txt)$', caseSensitive: false), '').trim();

  if (firstNonEmpty < lines.length) {
    final headingMatch =
        RegExp(r'^#{1,2}\s+(.+)$').firstMatch(lines[firstNonEmpty].trim());
    if (headingMatch != null) {
      var bodyStart = firstNonEmpty + 1;
      while (bodyStart < lines.length && lines[bodyStart].trim().isEmpty) {
        bodyStart++;
      }
      final body = lines.sublist(bodyStart).join('\n').trim();
      return (
        title: headingMatch.group(1)!.trim(),
        content: body.isNotEmpty ? body : normalized.trim(),
      );
    }
  }

  return (
    title: fallbackTitle,
    content: normalized.trim(),
  );
}

String buildSinglePostExportText(PostItem post, String ext) {
  final cleanBody = stripDuplicateLeadingHeading(post.content, post.title);
  if (ext == 'md') {
    if (post.title != null && post.title!.trim().isNotEmpty) {
      return '# ${post.title!.trim()}\n\n$cleanBody';
    }
    return post.content;
  }
  final plainBody = markdownToPlainText(cleanBody);
  if (post.title != null && post.title!.trim().isNotEmpty) {
    return '${post.title!.trim()}\n\n$plainBody';
  }
  return plainBody;
}

/// 当后端尚未实现 /api/v1/exports/markdown 或处于示例模式时，在端侧生成结构化汇总 Markdown。
String buildJournalMarkdownFromPosts(
  List<PostItem> posts, {
  DateTime? startDate,
  DateTime? endDate,
}) {
  final sorted = [...posts]
    ..sort((a, b) => a.recordTime.compareTo(b.recordTime));
  final momentCount =
      sorted.where((p) => p.type == PostType.moment).length;
  final articleCount =
      sorted.where((p) => p.type == PostType.article).length;

  final sb = StringBuffer()
    ..writeln('# Vellum 记录导出\n')
    ..writeln('- 时间范围：${_formatRangeLabel(startDate, endDate)}')
    ..writeln('- 记录统计：共 ${sorted.length} 条（动态 $momentCount 条，长文 $articleCount 篇）')
    ..writeln('- 导出时间：${formatDotDate(DateTime.now())} ${formatTime(DateTime.now())}');

  for (final post in sorted) {
    final isArticle = post.type == PostType.article;
    final localTime = post.recordTime.toLocal();
    sb
      ..writeln('\n---\n')
      ..write('## ${formatDotDate(localTime)} ${formatTime(localTime)} · ${isArticle ? '长文' : '动态'}');
    if (post.locationCity != null && post.locationCity!.trim().isNotEmpty) {
      sb.write(' · ${post.locationCity!.trim()}');
    }
    sb.writeln();

    if (isArticle && post.title != null && post.title!.trim().isNotEmpty) {
      sb.writeln('### ${post.title!.trim()}\n');
    }

    final body = isArticle
        ? stripDuplicateLeadingHeading(post.content, post.title).trim()
        : post.content.trim();
    if (body.isNotEmpty) {
      sb.writeln('$body\n');
    }

    if (post.images.isNotEmpty) {
      for (final img in post.images) {
        sb.writeln('![]($img)');
      }
    }
  }
  return sb.toString();
}

String _formatRangeLabel(DateTime? start, DateTime? end) {
  if (start != null && end != null) {
    return '${formatApiDate(start)} ~ ${formatApiDate(end)}';
  }
  if (start != null) return '${formatApiDate(start)} 至今';
  if (end != null) return '截至 ${formatApiDate(end)}';
  return '全部时间';
}
