import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vellum_app/core/location/city_locator.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/utils/markdown_io.dart';
import 'package:vellum_app/core/widgets/segmented_pill.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';
import 'package:vellum_app/data/models/models.dart';
import 'package:vellum_app/data/providers/app_providers.dart';
import 'package:vellum_app/features/compose/city_picker_sheet.dart';

/// 还原 Figma「8:21 素笺 · 发布与编辑」：
/// 顶部取消 / 动态·长文切换 / 发布按钮 + 无边框写作区 + 96×96 带移除角标图格 + 贴底工具条（选图 / 导入 md·txt / 城市定位胶囊）。
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _maxImages = 9;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  PostType _postType = PostType.moment;
  final List<String> _imagePaths = [];
  String? _city;
  bool _locating = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoDetectCity());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoDetectCity() async {
    setState(() => _locating = true);
    final res = await CityLocator.detectCurrentCity();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _city = res.city;
    });
    if (res.failed && res.city == null) {
      final picked = await CityPickerSheet.show(
        context,
        currentCity: _city,
        locationFailed: true,
      );
      if (!mounted || picked == null) return;
      setState(() => _city = picked.isEmpty ? null : picked);
    }
  }

  Future<void> _openCityPicker() async {
    final picked = await CityPickerSheet.show(
      context,
      currentCity: _city,
      locationFailed: false,
    );
    if (!mounted || picked == null) return;
    setState(() => _city = picked.isEmpty ? null : picked);
  }

  Future<void> _pickImages() async {
    if (_submitting || _imagePaths.length >= _maxImages) return;
    final remaining = _maxImages - _imagePaths.length;
    final files = await _imagePicker.pickMultiImage(limit: remaining);
    if (files.isEmpty || !mounted) return;
    setState(() {
      for (final f in files) {
        if (_imagePaths.length < _maxImages) {
          _imagePaths.add(f.path);
        }
      }
    });
  }

  Future<void> _importDocument() async {
    if (_submitting) return;
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown', 'txt'],
    );
    final path = res?.files.single.path;
    if (path == null || !mounted) return;

    final raw = await File(path).readAsString();
    final parsed = parseMarkdownOrTextContent(
      res!.files.single.name,
      raw,
    );
    if (!mounted) return;

    setState(() {
      _postType = PostType.article;
      _titleCtrl.text = parsed.title;
      _bodyCtrl.text = parsed.content;
    });
  }

  Future<void> _publish() async {
    if (_submitting) return;
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (_postType == PostType.article && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('长文正文内容不能为空')),
      );
      return;
    }
    if (body.isEmpty && _imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写点什么或选一张照片再发布')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(timelineProvider.notifier).submitPost(
            type: _postType,
            title: _postType == PostType.article ? title : null,
            content: body,
            locationCity: _city,
            localImagePaths: List.unmodifiable(_imagePaths),
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Editor app bar (Figma 8:38)
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    VellumTactile(
                      enabled: !_submitting,
                      onTap: _submitting ? null : () => context.pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '取消',
                          style: TextStyle(fontSize: 15, color: c.ink),
                        ),
                      ),
                    ),
                    const Spacer(),
                    VellumSegmentedPill<PostType>(
                      width: 144,
                      height: 40,
                      value: _postType,
                      onChanged: (next) => setState(() => _postType = next),
                      options: const [
                        SegmentedPillOption(
                          value: PostType.moment,
                          label: '动态',
                        ),
                        SegmentedPillOption(
                          value: PostType.article,
                          label: '长文',
                        ),
                      ],
                    ),
                    const Spacer(),
                    VellumButton(
                      width: 72,
                      height: 40,
                      padding: EdgeInsets.zero,
                      loading: _submitting,
                      onPressed: _submitting ? null : _publish,
                      backgroundColor: c.actionBg,
                      foregroundColor: c.actionText,
                      borderRadius: BorderRadius.circular(20),
                      child: const Text(
                        '发布',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Writing area (Figma 8:39)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VellumCollapsible(
                      expanded: _postType == PostType.article,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: TextField(
                          controller: _titleCtrl,
                          style: TextStyle(
                            fontSize: 25,
                            height: 38 / 25,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: '标题',
                            hintStyle: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: c.muted.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: null,
                      minLines: 5,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 15,
                        height: 28 / 15,
                        color: c.ink,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: _postType == PostType.article
                            ? '写下正文，支持 Markdown...'
                            : '此刻...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          height: 28 / 15,
                          color: c.muted.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    if (_imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_imagePaths.length, (idx) {
                          final thumbCacheW =
                              (96 * MediaQuery.devicePixelRatioOf(context))
                                  .round();
                          return VellumEntrance(
                            key: ValueKey(_imagePaths[idx]),
                            offsetY: 6,
                            duration: const Duration(milliseconds: 240),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_imagePaths[idx]),
                                    width: 96,
                                    height: 96,
                                    cacheWidth: thumbCacheW,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (!_submitting)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: VellumTactile(
                                      pressedScale: 0.85,
                                      onTap: () => setState(
                                        () => _imagePaths.removeAt(idx),
                                      ),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: c.canvas,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: VellumIcon(
                                          VellumIcons.closeSm,
                                          size: 12,
                                          color: c.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Attachment toolbar above keyboard (Figma 8:40)
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: c.canvas,
                border: Border(top: BorderSide(color: c.divider, width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  VellumTactile(
                    pressedScale: 0.88,
                    onTap: _pickImages,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: VellumIcon(
                        VellumIcons.chooseImages,
                        size: 24,
                        color: _imagePaths.length < _maxImages ? c.ink : c.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                  VellumTactile(
                    pressedScale: 0.88,
                    onTap: _importDocument,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: VellumIcon(
                        VellumIcons.importDoc,
                        size: 24,
                        color: c.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  VellumTactile(
                    pressedScale: 0.95,
                    onTap: _openCityPicker,
                    child: AnimatedContainer(
                      duration: VellumMotion.fast,
                      curve: VellumMotion.easeOut,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VellumIcon(
                            VellumIcons.location,
                            size: 16,
                            color: c.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _locating
                                ? '定位中...'
                                : (_city ?? '选择城市'),
                            style: TextStyle(
                              fontSize: 13,
                              color: _city != null ? c.inkSecondary : c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
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
