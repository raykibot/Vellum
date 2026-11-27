import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// 将 Framer Motion / SpringSimulation 的物理弹簧曲线映射为标准 Flutter [Curve]，
/// 用于弹窗、抽屉等由 [AnimationController] 驱动的非线性弹跳缩放与位移。
/// 注意：欠阻尼弹簧可能略微超过 1.0，切勿直接用于 Opacity / FadeTransition，透明度请搭配 [VellumMotion.easeOut]。
class VellumSpringCurve extends Curve {
  VellumSpringCurve(
    this.spring, {
    this.durationSeconds = 0.45,
  }) : _sim = SpringSimulation(spring, 0.0, 1.0, 0.0);

  final SpringDescription spring;
  final double durationSeconds;
  final SpringSimulation _sim;

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return _sim.x(t * durationSeconds);
  }
}

/// 素笺（Vellum）统一动效规范：精确对齐 `vellum-web` 的缓动函数、弹簧参数与节奏时长。
class VellumMotion {
  VellumMotion._();

  /// `cubic-bezier(0.22, 1, 0.36, 1)`：Web 端核心非线性减速曲线。
  static const Curve easeOut = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve easeIn = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve easeOutReverse = Curves.easeInOutCubic;

  /// 与 Web `TactileButton` / `SegmentedControl` / `Modal` / `Lightbox` 一致的物理弹簧参数。
  static const SpringDescription tapSpring =
      SpringDescription(mass: 1, stiffness: 520, damping: 32);
  static const SpringDescription pillSpring =
      SpringDescription(mass: 1, stiffness: 440, damping: 34);
  static const SpringDescription modalSpring =
      SpringDescription(mass: 1, stiffness: 420, damping: 32);
  static const SpringDescription gallerySpring =
      SpringDescription(mass: 1, stiffness: 380, damping: 32);

  static final Curve modalCurve =
      VellumSpringCurve(modalSpring, durationSeconds: 0.44);
  static final Curve galleryCurve =
      VellumSpringCurve(gallerySpring, durationSeconds: 0.44);

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration entrance = Duration(milliseconds: 340);

  static const Duration pagePush = Duration(milliseconds: 380);
  static const Duration pagePop = Duration(milliseconds: 360);
  static const Duration pageModal = Duration(milliseconds: 380);
  static const Duration pageModalPop = Duration(milliseconds: 340);
  static const Duration pageFade = Duration(milliseconds: 320);

  static const Duration dialog = Duration(milliseconds: 360);
  static const Duration dialogPop = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 380);
  static const Duration sheetPop = Duration(milliseconds: 320);
}

/// 复刻 Web `TactileButton` 的物理按压反馈（`whileTap: { scale: 0.96 }` + spring 520/32）。
/// 即使是极快的轻点（Fast Tap），也会产生可见的微缩回弹与轻触震动反馈，消除“干瘪/傻快”的手感。
class VellumTactile extends StatefulWidget {
  const VellumTactile({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.pressedScale = 0.96,
    this.pressedOpacity = 1.0,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double pressedScale;
  final double pressedOpacity;
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<VellumTactile> createState() => _VellumTactileState();
}

class _VellumTactileState extends State<VellumTactile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this, value: 1.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled || widget.onTap == null) return;
    setState(() => _pressed = true);
    _ctrl.animateWith(
      SpringSimulation(
        VellumMotion.tapSpring,
        _ctrl.value,
        widget.pressedScale,
        -1.5,
      ),
    );
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled || widget.onTap == null) return;
    setState(() => _pressed = false);
    if (widget.haptic) {
      HapticFeedback.selectionClick();
    }
    final mid = (1.0 + widget.pressedScale) / 2;
    if (_ctrl.value > mid) {
      _ctrl.animateWith(
        SpringSimulation(VellumMotion.tapSpring, _ctrl.value, 1.0, -3.2),
      );
    } else {
      _ctrl.animateWith(
        SpringSimulation(
          VellumMotion.tapSpring,
          _ctrl.value,
          1.0,
          _ctrl.velocity,
        ),
      );
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (_pressed) {
      setState(() => _pressed = false);
    }
    _ctrl.animateWith(
      SpringSimulation(
        VellumMotion.tapSpring,
        _ctrl.value,
        1.0,
        _ctrl.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.scale(
          scale: _ctrl.value,
          child: child,
        );
      },
      child: widget.child,
    );

    if (widget.pressedOpacity < 1.0) {
      content = AnimatedOpacity(
        opacity: _pressed ? widget.pressedOpacity : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: VellumMotion.easeOut,
        child: content,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.enabled && widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.enabled && widget.onTap != null ? _handleTapUp : null,
      onTapCancel: _handleTapCancel,
      child: content,
    );
  }
}

/// 复刻 Web `TactileButton`：结合物理弹簧按压、状态色过渡与内联加载指示器展开动画。
class VellumButton extends StatelessWidget {
  const VellumButton({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.height,
    this.width,
    this.padding,
    this.borderRadius,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final double pressedScale;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = borderRadius ?? BorderRadius.circular(24);
    final bg = backgroundColor ?? Colors.transparent;
    final fg = foregroundColor ?? Theme.of(context).colorScheme.onPrimary;

    return VellumTactile(
      enabled: enabled,
      onTap: onPressed,
      pressedScale: pressedScale,
      child: AnimatedOpacity(
        opacity: (onPressed == null && !loading) ? 0.55 : (loading ? 0.85 : 1.0),
        duration: VellumMotion.fast,
        curve: VellumMotion.easeOut,
        child: AnimatedContainer(
          duration: VellumMotion.fast,
          curve: VellumMotion.easeOut,
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: borderColor != null ? Border.all(color: borderColor!) : null,
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg),
            child: IconTheme.merge(
              data: IconThemeData(color: fg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: VellumMotion.easeOut,
                    child: loading
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AnimatedOpacity(
                              opacity: loading ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: AnimatedScale(
                                scale: loading ? 1.0 : 0.6,
                                duration: const Duration(milliseconds: 200),
                                curve: VellumMotion.easeOut,
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: fg,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 复刻 Web `motion.div initial={{ opacity: 0, y }} animate={{ opacity: 1, y: 0 }}` 入场渐显位移。
class VellumEntrance extends StatefulWidget {
  const VellumEntrance({
    super.key,
    required this.child,
    this.offsetY = 10.0,
    this.duration = VellumMotion.entrance,
    this.delay = Duration.zero,
  });

  final Widget child;
  final double offsetY;
  final Duration duration;
  final Duration delay;

  @override
  State<VellumEntrance> createState() => _VellumEntranceState();
}

class _VellumEntranceState extends State<VellumEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _ctrl, curve: VellumMotion.easeOut);
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _curved,
        builder: (context, child) {
          final v = _curved.value;
          return Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, widget.offsetY * (1.0 - v)),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 复刻 Web `AnimatePresence` 高度折叠/展开动画（`cubic-bezier(0.22, 1, 0.36, 1)` + 淡入微移）。
class VellumCollapsible extends StatelessWidget {
  const VellumCollapsible({
    super.key,
    required this.expanded,
    required this.child,
    this.duration = VellumMotion.medium,
  });

  final bool expanded;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSize(
        duration: duration,
        reverseDuration: duration,
        curve: VellumMotion.easeOut,
        alignment: Alignment.topCenter,
        child: expanded
            ? TweenAnimationBuilder<double>(
                key: const ValueKey(true),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: duration,
                curve: VellumMotion.easeOut,
                builder: (context, v, c) {
                  return Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -6 * (1.0 - v)),
                      child: c,
                    ),
                  );
                },
                child: child,
              )
            : const SizedBox(
                key: ValueKey(false),
                width: double.infinity,
                height: 0,
              ),
      ),
    );
  }
}

/// 轻柔呼吸脉冲动画，用于骨架屏与生物识别验证提示。
class VellumPulse extends StatefulWidget {
  const VellumPulse({
    super.key,
    required this.child,
    this.active = true,
    this.minOpacity = 0.42,
    this.duration = const Duration(milliseconds: 1100),
  });

  final Widget child;
  final bool active;
  final double minOpacity;
  final Duration duration;

  @override
  State<VellumPulse> createState() => _VellumPulseState();
}

class _VellumPulseState extends State<VellumPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: widget.minOpacity, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.active) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant VellumPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.animateTo(
          1.0,
          duration: VellumMotion.fast,
          curve: VellumMotion.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}
