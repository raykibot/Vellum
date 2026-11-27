import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/network/api_client.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/utils/formatters.dart';
import 'package:vellum_app/core/utils/markdown_io.dart';
import 'package:vellum_app/core/widgets/vellum_dialogs.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';
import 'package:vellum_app/data/providers/app_providers.dart';

enum _ExportRange { days7, days30, custom }

enum _ExportFormat { markdown, zip }

/// 还原 Figma「8:42 素笺 · AI 阶段导出」：
/// 顶部返回与导出标题 + 大标题「AI 阶段导出」+ 时间范围胶囊 + 区间回显框 + 双格式卡片 + 底部「导出并分享给 AI」主按钮。
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _ExportRange _range = _ExportRange.days30;
  _ExportFormat _format = _ExportFormat.zip;
  late DateTime _customStart;
  late DateTime _customEnd;
  bool _exporting = false;
  double? _progress;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _customEnd = now;
    _customStart = now.subtract(const Duration(days: 29));
  }

  (DateTime start, DateTime end) get _resolvedInterval {
    final now = DateTime.now();
    switch (_range) {
      case _ExportRange.days7:
        return (now.subtract(const Duration(days: 6)), now);
      case _ExportRange.days30:
        return (now.subtract(const Duration(days: 29)), now);
      case _ExportRange.custom:
        return (_customStart, _customEnd);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showVellumDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
      helpText: '选择导出时间区间',
    );
    if (picked != null && mounted) {
      setState(() {
        _range = _ExportRange.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
        _errorMsg = null;
      });
    }
  }

  Future<void> _exportAndShare() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _progress = null;
      _errorMsg = null;
    });

    final (start, end) = _resolvedInterval;
    final auth = ref.read(authProvider);

    try {
      final tmpDir = await getTemporaryDirectory();
      final startApi = formatApiDate(start);
      final endApi = formatApiDate(end);

      if (auth.demoMode) {
        await _exportFromLocalCache(
          tmpDir: tmpDir,
          start: start,
          end: end,
          notice: _format == _ExportFormat.zip
              ? '示例模式已导出结构化 Markdown 文件'
              : null,
        );
        return;
      }

      if (_format == _ExportFormat.zip) {
        final target = p.join(
          tmpDir.path,
          'vellum-export-${startApi.replaceAll('-', '')}-${endApi.replaceAll('-', '')}.zip',
        );
        final res = await ref.read(vellumApiProvider).downloadExportZip(
              savePath: target,
              startDate: startApi,
              endDate: endApi,
              onProgress: (received, total) {
                if (mounted && total > 0) {
                  setState(() => _progress = received / total);
                }
              },
            );
        await Share.shareXFiles([XFile(res.file.path)]);
      } else {
        final target = p.join(
          tmpDir.path,
          'vellum-export-${startApi.replaceAll('-', '')}-${endApi.replaceAll('-', '')}.md',
        );
        try {
          final res = await ref.read(vellumApiProvider).downloadExportMarkdown(
                savePath: target,
                startDate: startApi,
                endDate: endApi,
              );
          await Share.shareXFiles([XFile(res.file.path)]);
        } on ApiException catch (e) {
          if (e.code == 501) {
            await _exportFromLocalCache(
              tmpDir: tmpDir,
              start: start,
              end: end,
              notice: '已基于本地缓存记录生成 Markdown 并分享',
            );
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _exportFromLocalCache({
    required Directory tmpDir,
    required DateTime start,
    required DateTime end,
    String? notice,
  }) async {
    final startBound = DateTime(start.year, start.month, start.day);
    final endBound = DateTime(end.year, end.month, end.day + 1);
    final all = ref.read(timelineProvider).remotePosts;
    final matched = all.where((p) {
      final t = p.recordTime.toLocal();
      return !t.isBefore(startBound) && t.isBefore(endBound);
    }).toList();

    if (matched.isEmpty) {
      throw ApiException(404, '所选时间范围内暂无可导出的记录');
    }

    final md = buildJournalMarkdownFromPosts(
      matched,
      startDate: start,
      endDate: end,
    );
    final file = File(
      p.join(
        tmpDir.path,
        'vellum-export-${formatApiDate(start).replaceAll('-', '')}-${formatApiDate(end).replaceAll('-', '')}.md',
      ),
    );
    await file.writeAsString(md, flush: true);
    if (notice != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice)),
      );
    }
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    final (start, end) = _resolvedInterval;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Export app bar (Figma 8:59)
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    VellumTactile(
                      pressedScale: 0.88,
                      enabled: !_exporting,
                      onTap: _exporting ? null : () => context.pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: VellumIcon(
                          VellumIcons.back,
                          size: 24,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    Text(
                      '导出',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: VellumEntrance(
                  offsetY: 10,
                  duration: const Duration(milliseconds: 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 阶段导出',
                        style: TextStyle(
                          fontSize: 26,
                          height: 38 / 26,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 42),

                      // Date range section (Figma 8:125 - 8:135)
                      Text(
                        '时间范围',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _RangeChip(
                            label: '近 7 天',
                            selected: _range == _ExportRange.days7,
                            onTap: () => setState(() {
                              _range = _ExportRange.days7;
                              _errorMsg = null;
                            }),
                          ),
                          const SizedBox(width: 10),
                          _RangeChip(
                            label: '近 30 天',
                            selected: _range == _ExportRange.days30,
                            onTap: () => setState(() {
                              _range = _ExportRange.days30;
                              _errorMsg = null;
                            }),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _RangeChip(
                              label: '自定义区间',
                              selected: _range == _ExportRange.custom,
                              onTap: _pickCustomRange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      VellumTactile(
                        pressedScale: 0.985,
                        onTap: _pickCustomRange,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AnimatedSwitcher(
                            duration: VellumMotion.fast,
                            switchInCurve: VellumMotion.easeOut,
                            child: Row(
                              key: ValueKey('${formatDotDate(start)}_${formatDotDate(end)}'),
                              children: [
                                Text(
                                  formatDotDate(start),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: c.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '—',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.muted,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatDotDate(end),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: c.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 42),

                      // Format section (Figma 8:136 - 8:152)
                      Text(
                        '导出格式',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FormatCard(
                        icon: VellumIcons.formatMd,
                        title: 'Markdown 文档（.md）',
                        subtitle: '纯文本与图片链接，轻量易读',
                        selected: _format == _ExportFormat.markdown,
                        onTap: () => setState(() {
                          _format = _ExportFormat.markdown;
                          _errorMsg = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _FormatCard(
                        icon: VellumIcons.formatZip,
                        title: '含图压缩包（.zip）',
                        subtitle: '文档与原始图片，完整保留记录',
                        selected: _format == _ExportFormat.zip,
                        onTap: () => setState(() {
                          _format = _ExportFormat.zip;
                          _errorMsg = null;
                        }),
                      ),

                      if (_errorMsg != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          _errorMsg!,
                          style: TextStyle(fontSize: 12.5, color: c.danger),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom pinned CTA (Figma 8:61)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: VellumButton(
                width: double.infinity,
                height: 52,
                loading: _exporting,
                onPressed: _exporting ? null : _exportAndShare,
                backgroundColor: c.actionBg,
                foregroundColor: c.actionText,
                borderRadius: BorderRadius.circular(26),
                child: Text(
                  _exporting
                      ? (_progress != null
                          ? '打包中 ${(_progress! * 100).round()}%'
                          : '正在导出...')
                      : '导出并分享给 AI',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    return VellumTactile(
      pressedScale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: VellumMotion.easeOut,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.actionBg : c.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedDefaultTextStyle(
          duration: VellumMotion.fast,
          curve: VellumMotion.easeOut,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? c.actionText : c.ink,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    return VellumTactile(
      pressedScale: 0.98,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: VellumMotion.easeOut,
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.ink : c.divider,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            VellumIcon(icon, size: 22, color: c.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      height: 24 / 14,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 20 / 11,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: VellumMotion.fast,
              switchInCurve: VellumMotion.easeOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: VellumIcon(
                selected
                    ? VellumIcons.radioSelected
                    : VellumIcons.radioUnselected,
                key: ValueKey(selected),
                size: 20,
                color: selected ? c.ink : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
