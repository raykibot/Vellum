import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:vellum_app/core/media/media_helper.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';

/// 全屏看图画廊：支持透明渐变路由、Hero 共享过渡、双指缩放、左右滑动切换与下拉物理阻尼关闭（对齐 Web Lightbox）。
class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTagPrefix,
    this.baseUrl = '',
    this.token,
  });

  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;
  final String baseUrl;
  final String? token;

  static Route<void> route({
    required List<String> images,
    required int initialIndex,
    required String heroTagPrefix,
    String baseUrl = '',
    String? token,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => PhotoGalleryScreen(
        images: images,
        initialIndex: initialIndex,
        heroTagPrefix: heroTagPrefix,
        baseUrl: baseUrl,
        token: token,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: animation.status == AnimationStatus.reverse
              ? VellumMotion.easeIn
              : VellumMotion.easeOut,
        );
        return FadeTransition(opacity: curve, child: child);
      },
    );
  }

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final PhotoViewScaleStateController _scaleStateCtrl;
  late final AnimationController _dismissCtrl;
  late int _currentIndex;
  double _dragOffsetY = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _scaleStateCtrl = PhotoViewScaleStateController();
    _dismissCtrl = AnimationController.unbounded(vsync: this, value: 0.0)
      ..addListener(() {
        if (mounted) {
          setState(() => _dragOffsetY = _dismissCtrl.value);
        }
      });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _scaleStateCtrl.dispose();
    _dismissCtrl.dispose();
    super.dispose();
  }

  bool get _canDragDismiss =>
      _scaleStateCtrl.scaleState == PhotoViewScaleState.initial;

  void _onVerticalDragStart(DragStartDetails details) {
    if (!_canDragDismiss) return;
    _dismissCtrl.stop();
    setState(() => _isDragging = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    _dismissCtrl.value += details.delta.dy;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    setState(() => _isDragging = false);
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffsetY.abs() > 110 || velocity.abs() > 700) {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop();
      return;
    }
    _dismissCtrl.animateWith(
      SpringSimulation(
        VellumMotion.gallerySpring,
        _dragOffsetY,
        0.0,
        velocity / 1000,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffsetY.abs() / 280).clamp(0.0, 1.0);
    final backdropAlpha = (1.0 - progress * 0.65).clamp(0.2, 1.0);
    final galleryScale = (1.0 - progress * 0.18).clamp(0.82, 1.0);
    final controlsOpacity = _isDragging ? (1.0 - progress * 3).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: backdropAlpha),
            ),
          ),
          GestureDetector(
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Transform.scale(
                scale: galleryScale,
                child: PhotoViewGallery.builder(
                  pageController: _pageCtrl,
                  itemCount: widget.images.length,
                  onPageChanged: (index) => setState(() {
                    _currentIndex = index;
                    _scaleStateCtrl.scaleState = PhotoViewScaleState.initial;
                  }),
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  builder: (context, index) {
                    final src = widget.images[index];
                    return PhotoViewGalleryPageOptions.customChild(
                      scaleStateController: _scaleStateCtrl,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3.0,
                      heroAttributes: PhotoViewHeroAttributes(
                        tag: '${widget.heroTagPrefix}$index',
                      ),
                      child: Center(
                        child: VellumImage(
                          source: src,
                          baseUrl: widget.baseUrl,
                          token: widget.token,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedOpacity(
              opacity: controlsOpacity,
              duration: const Duration(milliseconds: 140),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    VellumTactile(
                      pressedScale: 0.90,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const VellumIcon(
                          VellumIcons.back,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
