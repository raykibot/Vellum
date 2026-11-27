import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vellum_app/core/media/media_helper.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/utils/formatters.dart';
import 'package:vellum_app/core/utils/markdown_io.dart';
import 'package:vellum_app/core/widgets/segmented_pill.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';
import 'package:vellum_app/data/models/models.dart';
import 'package:vellum_app/data/providers/app_providers.dart';
import 'package:vellum_app/features/detail/photo_gallery_screen.dart';

/// 还原 Figma「4:2 素笺 Vellum · 首页」：
/// 极简顶栏（含设置入口）+ 胶囊筛选行 + 按月分组时间流（左侧周日/大号日期 + 右侧图文/长文摘要）+ 右下角悬浮 + 按钮。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(timelineProvider.notifier).loadInitial();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(timelineProvider.notifier).loadMore();
    }
  }

  Future<void> _pickDateRange() async {
    final current = ref.read(timelineProvider);
    final c = context.vellum;
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current.startDate != null && current.endDate != null
          ? DateTimeRange(start: current.startDate!, end: current.endDate!)
          : null,
      helpText: '按日期筛选',
      saveText: '确定',
      cancelText: '取消',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: c.actionBg,
                  onPrimary: c.actionText,
                  surface: c.canvas,
                  onSurface: c.ink,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      ref
          .read(timelineProvider.notifier)
          .setDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    final auth = ref.watch(authProvider);
    final timeline = ref.watch(timelineProvider);
    final posts = timeline.visiblePosts;
    final flatItems = _buildFlatItems(posts);
    final hasDateFilter =
        timeline.startDate != null || timeline.endDate != null;
    final listStateKey = ValueKey(
      '${timeline.filter}_${timeline.startDate}_${timeline.endDate}_${timeline.isLoading && posts.isEmpty}_${posts.isEmpty}',
    );

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top app bar (Figma 4:4) + Settings entry
                SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        VellumIcon(
                          VellumIcons.notebookMark,
                          size: 24,
                          color: c.ink,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Vellum',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: c.ink,
                          ),
                        ),
                        const Spacer(),
                        _TopIconButton(
                          icon: VellumIcons.search,
                          tooltip: '搜索',
                          onTap: () {
                            setState(() {
                              _searchVisible = !_searchVisible;
                              if (!_searchVisible) {
                                _searchCtrl.clear();
                                ref
                                    .read(timelineProvider.notifier)
                                    .setKeyword('');
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        _TopIconButton(
                          icon: VellumIcons.export,
                          tooltip: 'AI 导出',
                          onTap: () => context.push('/export'),
                        ),
                        const SizedBox(width: 16),
                        _TopIconButton(
                          icon: VellumIcons.settings,
                          tooltip: '设置',
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),

                // Inline collapsible search input
                VellumCollapsible(
                  expanded: _searchVisible,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          VellumIcon(
                            VellumIcons.search,
                            size: 16,
                            color: c.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: _searchVisible,
                              onChanged: (v) => ref
                                  .read(timelineProvider.notifier)
                                  .setKeyword(v),
                              style: TextStyle(fontSize: 13.5, color: c.ink),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                                hintText: '搜索正文、标题或城市',
                                hintStyle: TextStyle(
                                  fontSize: 13.5,
                                  color: c.muted,
                                ),
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            VellumTactile(
                              pressedScale: 0.88,
                              onTap: () {
                                _searchCtrl.clear();
                                ref
                                    .read(timelineProvider.notifier)
                                    .setKeyword('');
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: VellumIcon(
                                  VellumIcons.closeSm,
                                  size: 14,
                                  color: c.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Timeline filters row (Figma 4:5)
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        VellumSegmentedPill<PostFilterType>(
                          width: 206,
                          height: 40,
                          value: timeline.filter,
                          onChanged: (next) => ref
                              .read(timelineProvider.notifier)
                              .setFilter(next),
                          options: const [
                            SegmentedPillOption(
                              value: PostFilterType.all,
                              label: '全部',
                            ),
                            SegmentedPillOption(
                              value: PostFilterType.moment,
                              label: '动态',
                            ),
                            SegmentedPillOption(
                              value: PostFilterType.article,
                              label: '长文',
                            ),
                          ],
                        ),
                        const Spacer(),
                        VellumTactile(
                          pressedScale: 0.90,
                          onTap: _pickDateRange,
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VellumIcon(
                                  VellumIcons.calendarFilter,
                                  size: 22,
                                  color: hasDateFilter ? c.ink : c.inkSecondary,
                                ),
                                if (hasDateFilter)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: c.ink,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Active date range chip
                VellumCollapsible(
                  expanded: hasDateFilter,
                  child: hasDateFilter
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(24, 6, 24, 2),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: VellumTactile(
                              pressedScale: 0.95,
                              onTap: () => ref
                                  .read(timelineProvider.notifier)
                                  .setDateRange(null, null),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${formatDotDate(timeline.startDate!)} — ${formatDotDate(timeline.endDate!)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: c.inkSecondary,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    VellumIcon(
                                      VellumIcons.closeSm,
                                      size: 11,
                                      color: c.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Offline / pending outbox strip
                VellumCollapsible(
                  expanded: timeline.pendingPosts.isNotEmpty ||
                      timeline.offlineBanner,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: VellumTactile(
                      pressedScale: 0.98,
                      onTap: () => context.push('/settings'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                timeline.pendingPosts.isNotEmpty
                                    ? '本地有 ${timeline.pendingPosts.length} 条记录待同步到服务器'
                                    : '当前离线，正在展示本地缓存内容',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.inkSecondary,
                                ),
                              ),
                            ),
                            Text(
                              timeline.pendingPosts.isNotEmpty ? '查看' : '重试',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: c.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Monthly timeline list (Figma 4:6)
                Expanded(
                  child: RefreshIndicator(
                    color: c.ink,
                    backgroundColor: c.canvas,
                    onRefresh: () =>
                        ref.read(timelineProvider.notifier).refresh(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      reverseDuration: const Duration(milliseconds: 180),
                      switchInCurve: VellumMotion.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: timeline.isLoading && posts.isEmpty
                          ? KeyedSubtree(
                              key: listStateKey,
                              child: _buildSkeleton(c),
                            )
                          : posts.isEmpty
                              ? ListView(
                                  key: listStateKey,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.5,
                                      child: Center(
                                        child: Text(
                                          timeline.errorMessage ??
                                              '暂无记录，点击右下角开始写下此刻',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: c.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  key: listStateKey,
                                  controller: _scrollCtrl,
                                  scrollCacheExtent:
                                      const ScrollCacheExtent.pixels(600),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 108),
                                  itemCount: flatItems.length +
                                      (timeline.isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= flatItems.length) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.8,
                                              color: c.muted,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final item = flatItems[index];
                                    if (item is _MonthHeaderItem) {
                                      return Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          24,
                                          item.isFirst ? 22 : 12,
                                          24,
                                          20,
                                        ),
                                        child: Text(
                                          item.month,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 22 / 14,
                                            fontWeight: FontWeight.w700,
                                            color: c.ink,
                                          ),
                                        ),
                                      );
                                    }
                                    if (item is _DividerItem) {
                                      return Container(
                                        height: 1,
                                        margin: const EdgeInsets.only(
                                          left: 80,
                                          right: 24,
                                          top: 24,
                                          bottom: 24,
                                        ),
                                        color: c.divider,
                                      );
                                    }
                                    final postItem = item as _PostEntryItem;
                                    return RepaintBoundary(
                                      child: _TimelineEntryCard(
                                        post: postItem.post,
                                        baseUrl: auth.apiBaseUrl,
                                        token: auth.token,
                                        onTap: () => context.push(
                                          '/detail/${Uri.encodeComponent(postItem.post.id)}',
                                          extra: postItem.post,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ),
              ],
            ),

            // Quick entry FAB (Figma 4:7)
            Positioned(
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: VellumTactile(
                pressedScale: 0.91,
                onTap: () => context.push('/compose'),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.actionBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x21000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: VellumIcon(
                    VellumIcons.plus,
                    size: 24,
                    color: c.actionText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(VellumColors c) {
    return VellumPulse(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 46,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 16,
                      width: 180,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_TimelineListItem> _buildFlatItems(List<PostItem> posts) {
    final map = <String, List<PostItem>>{};
    for (final post in posts) {
      final key = formatMonthKey(post.recordTime);
      map.putIfAbsent(key, () => []).add(post);
    }

    final result = <_TimelineListItem>[];
    final entries = map.entries.toList();
    for (var gIdx = 0; gIdx < entries.length; gIdx++) {
      final entry = entries[gIdx];
      result.add(_MonthHeaderItem(month: entry.key, isFirst: gIdx == 0));
      for (var i = 0; i < entry.value.length; i++) {
        result.add(_PostEntryItem(entry.value[i]));
        final isLastOverall =
            gIdx == entries.length - 1 && i == entry.value.length - 1;
        if (!isLastOverall) {
          result.add(const _DividerItem());
        }
      }
    }
    return result;
  }
}

sealed class _TimelineListItem {
  const _TimelineListItem();
}

class _MonthHeaderItem extends _TimelineListItem {
  const _MonthHeaderItem({required this.month, required this.isFirst});

  final String month;
  final bool isFirst;
}

class _PostEntryItem extends _TimelineListItem {
  const _PostEntryItem(this.post);

  final PostItem post;
}

class _DividerItem extends _TimelineListItem {
  const _DividerItem();
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    return Tooltip(
      message: tooltip,
      child: VellumTactile(
        pressedScale: 0.88,
        pressedOpacity: 0.7,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: VellumIcon(icon, size: 24, color: c.ink),
        ),
      ),
    );
  }
}

class _TimelineEntryCard extends StatelessWidget {
  const _TimelineEntryCard({
    required this.post,
    required this.baseUrl,
    required this.token,
    required this.onTap,
  });

  final PostItem post;
  final String baseUrl;
  final String? token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    final meta = formatTimelineMeta(post.recordTime, post.locationCity);
    final isArticle = post.type == PostType.article;

    return VellumTactile(
      pressedScale: 0.985,
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left date column (Figma: weekday 11px + day 28px SemiBold)
            SizedBox(
              width: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatWeekday(post.recordTime),
                    style: TextStyle(
                      fontSize: 11,
                      height: 18 / 11,
                      color: c.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDay(post.recordTime),
                    style: TextStyle(
                      fontSize: 28,
                      height: 32 / 28,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right content column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isArticle) ...[
                    Text(
                      post.title?.isNotEmpty == true ? post.title! : '无题',
                      style: TextStyle(
                        fontSize: 17,
                        height: 26 / 17,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      stripMarkdown(
                        stripDuplicateLeadingHeading(
                          post.content,
                          post.title,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 25 / 14,
                        color: c.ink,
                      ),
                    ),
                  ] else ...[
                    if (post.content.trim().isNotEmpty)
                      Text(
                        post.content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 26 / 15,
                          color: c.ink,
                        ),
                      ),
                    if (post.images.isNotEmpty) ...[
                      if (post.content.trim().isNotEmpty)
                        const SizedBox(height: 16),
                      _MomentThumbnailGrid(
                        postId: post.id,
                        images: post.images,
                        baseUrl: baseUrl,
                        token: token,
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta,
                          style: TextStyle(
                            fontSize: 11,
                            height: 18 / 11,
                            color: c.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (post.isPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.pendingStatus == SyncStatus.failed
                                ? '同步失败'
                                : '待同步',
                            style: TextStyle(
                              fontSize: 10,
                              color: post.pendingStatus == SyncStatus.failed
                                  ? c.danger
                                  : c.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentThumbnailGrid extends StatelessWidget {
  const _MomentThumbnailGrid({
    required this.postId,
    required this.images,
    required this.baseUrl,
    required this.token,
  });

  final String postId;
  final List<String> images;
  final String baseUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(images.length, (idx) {
        final src = images[idx];
        final heroTag = 'post_${postId}_img_$idx';
        return VellumTactile(
          pressedScale: 0.96,
          onTap: () {
            Navigator.of(context).push(
              PhotoGalleryScreen.route(
                images: images,
                initialIndex: idx,
                heroTagPrefix: 'post_${postId}_img_',
                baseUrl: baseUrl,
                token: token,
              ),
            );
          },
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: VellumImage(
                source: src,
                baseUrl: baseUrl,
                token: token,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }),
    );
  }
}
