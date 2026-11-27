import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vellum_app/core/media/media_helper.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/utils/formatters.dart';
import 'package:vellum_app/core/utils/markdown_io.dart';
import 'package:vellum_app/core/widgets/vellum_dialogs.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';
import 'package:vellum_app/data/models/models.dart';
import 'package:vellum_app/data/providers/app_providers.dart';
import 'package:vellum_app/features/detail/photo_gallery_screen.dart';

/// 还原 Figma「8:2 素笺 · 记录详情」：
/// 极简顶栏（返回 + 导出 .md/.txt + 更多删除）+ 日期城市元数据 + 杂志感 Markdown 排版 + 大圆角配图画廊。
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  final String postId;
  final PostItem? initialPost;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  PostItem? _post;
  bool _loadingBody = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost ??
        ref.read(timelineProvider.notifier).findById(widget.postId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFullIfNeeded());
  }

  Future<void> _loadFullIfNeeded() async {
    final current = _post;
    if (current == null || !current.contentTruncated) return;
    setState(() => _loadingBody = true);
    final loaded =
        await ref.read(timelineProvider.notifier).loadPostDetail(current);
    if (mounted) {
      setState(() {
        _post = loaded;
        _loadingBody = false;
      });
    }
  }

  Future<void> _exportSingle(String ext) async {
    final post = _post;
    if (post == null) return;
    try {
      final text = buildSinglePostExportText(post, ext);
      final rawTitle = (post.title?.trim().isNotEmpty == true
              ? post.title!.trim()
              : 'vellum-${post.id.substring(0, post.id.length >= 8 ? 8 : post.id.length)}')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, '$rawTitle.$ext'));
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles([XFile(file.path)], subject: '$rawTitle.$ext');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    }
  }

  void _showExportSheet() {
    showVellumBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.vellum;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '另存 / 分享记录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 14),
                _SheetActionTile(
                  title: '导出为 Markdown（.md）',
                  subtitle: '保留标题与 Markdown 排版结构',
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportSingle('md');
                  },
                ),
                const SizedBox(height: 10),
                _SheetActionTile(
                  title: '导出为纯文本（.txt）',
                  subtitle: '去除 Markdown 标记，适合直接阅读',
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportSingle('txt');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreSheet() {
    showVellumBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetActionTile(
                title: '删除这条记录',
                subtitle: '从时间流中移除该条记录',
                destructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final post = _post;
    if (post == null || _deleting) return;
    final c = context.vellum;

    final confirmed = await showVellumDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          '确认删除？',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        content: Text(
          '删除后将不再在时间流中展示。',
          style: TextStyle(fontSize: 13.5, color: c.inkSecondary),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              VellumButton(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: Colors.transparent,
                foregroundColor: c.muted,
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消', style: TextStyle(fontSize: 13.5)),
              ),
              const SizedBox(width: 8),
              VellumButton(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: c.danger,
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.circular(18),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '删除',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(timelineProvider.notifier).deletePost(post);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    final auth = ref.watch(authProvider);
    final post = _post;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Detail app bar (Figma 8:19)
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    VellumTactile(
                      pressedScale: 0.88,
                      onTap: () => context.pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: VellumIcon(
                          VellumIcons.back,
                          size: 24,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const Spacer(),
                    VellumTactile(
                      pressedScale: 0.88,
                      onTap: _showExportSheet,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: VellumIcon(
                          VellumIcons.export,
                          size: 24,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    VellumTactile(
                      pressedScale: 0.88,
                      enabled: !_deleting,
                      onTap: _deleting ? null : _showMoreSheet,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: VellumIcon(
                          VellumIcons.moreVertical,
                          size: 24,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Article / Moment content (Figma 8:20)
            Expanded(
              child: post == null
                  ? Center(
                      child: Text(
                        '记录不存在',
                        style: TextStyle(fontSize: 14, color: c.muted),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                      child: VellumEntrance(
                        offsetY: 8,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatDetailMeta(
                                  post.recordTime, post.locationCity),
                              style: TextStyle(
                                fontSize: 11,
                                height: 20 / 11,
                                color: c.muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (post.type == PostType.article &&
                                post.title?.isNotEmpty == true) ...[
                              const SizedBox(height: 26),
                              Text(
                                post.title!,
                                style: TextStyle(
                                  fontSize: 26,
                                  height: 38 / 26,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (_loadingBody)
                              VellumPulse(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: List.generate(
                                    4,
                                    (i) => Container(
                                      height: 16,
                                      width: i == 3 ? 200 : double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: c.surface,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              _buildBodyContent(post, c),

                            if (post.images.isNotEmpty) ...[
                              const SizedBox(height: 30),
                              _DetailPhotoGrid(
                                postId: post.id,
                                images: post.images,
                                baseUrl: auth.apiBaseUrl,
                                token: auth.token,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(PostItem post, VellumColors c) {
    final cleanBody = post.type == PostType.article
        ? stripDuplicateLeadingHeading(post.content, post.title)
        : post.content;

    if (cleanBody.trim().isEmpty) return const SizedBox.shrink();

    if (post.type == PostType.moment) {
      return SelectionArea(
        child: Text(
          cleanBody,
          style: TextStyle(
            fontSize: 15,
            height: 28 / 15,
            color: c.ink,
          ),
        ),
      );
    }

    return SelectionArea(
      child: MarkdownBody(
        data: cleanBody,
        selectable: false,
        styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 15,
          height: 28 / 15,
          color: c.ink,
        ),
        pPadding: const EdgeInsets.only(bottom: 14),
        h1: TextStyle(
          fontSize: 22,
          height: 32 / 22,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
        h1Padding: const EdgeInsets.only(top: 16, bottom: 10),
        h2: TextStyle(
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
        h2Padding: const EdgeInsets.only(top: 18, bottom: 8),
        h3: TextStyle(
          fontSize: 16,
          height: 26 / 16,
          fontWeight: FontWeight.w600,
          color: c.ink,
        ),
        h3Padding: const EdgeInsets.only(top: 14, bottom: 6),
        blockquote: TextStyle(
          fontSize: 14,
          height: 27 / 14,
          color: c.inkSecondary,
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(16, 2, 0, 2),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: c.divider, width: 2),
          ),
        ),
        listBullet: TextStyle(
          fontSize: 15,
          height: 30 / 15,
          color: c.ink,
        ),
        listIndent: 18,
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.5,
          backgroundColor: c.surface,
          color: c.ink,
        ),
        codeblockPadding: const EdgeInsets.all(14),
        codeblockDecoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.divider),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.divider)),
        ),
      ),
    ),
    );
  }
}

class _DetailPhotoGrid extends StatelessWidget {
  const _DetailPhotoGrid({
    required this.postId,
    required this.images,
    required this.baseUrl,
    required this.token,
  });

  final String postId;
  final List<String> images;
  final String baseUrl;
  final String? token;

  void _openGallery(BuildContext context, int index) {
    Navigator.of(context).push(
      PhotoGalleryScreen.route(
        images: images,
        initialIndex: index,
        heroTagPrefix: 'detail_${postId}_img_',
        baseUrl: baseUrl,
        token: token,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return VellumTactile(
        pressedScale: 0.985,
        onTap: () => _openGallery(context, 0),
        child: Hero(
          tag: 'detail_${postId}_img_0',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 342 / 214,
              child: VellumImage(
                source: images.first,
                baseUrl: baseUrl,
                token: token,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );
    }

    final crossAxisCount = images.length == 2 || images.length == 4 ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: images.length == 2 ? 4 / 3 : 1,
      ),
      itemBuilder: (context, idx) {
        return VellumTactile(
          pressedScale: 0.96,
          onTap: () => _openGallery(context, idx),
          child: Hero(
            tag: 'detail_${postId}_img_$idx',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: VellumImage(
                source: images[idx],
                baseUrl: baseUrl,
                token: token,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    return VellumTactile(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: destructive ? c.danger : c.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11.5, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
