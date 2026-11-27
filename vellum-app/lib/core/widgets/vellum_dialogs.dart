import 'package:flutter/material.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';

/// 复刻 Web `Modal.tsx` 的居中弹窗过渡：弹簧缩放（0.94 -> 1.0）+ 微幅上浮 + 非线性背景渐显。
Future<T?> showVellumDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: VellumMotion.dialog,
    pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final isForward = animation.status != AnimationStatus.reverse;
      final fadeCurve = CurvedAnimation(
        parent: animation,
        curve: isForward ? VellumMotion.easeOut : VellumMotion.easeIn,
      );
      final motionCurve = CurvedAnimation(
        parent: animation,
        curve: isForward ? VellumMotion.modalCurve : VellumMotion.easeIn,
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, widgetChild) {
          final m = motionCurve.value;
          final scale = 0.94 + 0.06 * m;
          final offsetY = 12.0 * (1.0 - m);
          return FadeTransition(
            opacity: fadeCurve,
            child: Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform.scale(
                scale: scale,
                child: widgetChild,
              ),
            ),
          );
        },
        child: child,
      );
    },
  );
}

/// 统一的底部弹出抽屉动画样式（380ms 弹出 / 280ms 收起 + Web `easeOut` 非线性曲线 + 极简顶栏指示条）。
Future<T?> showVellumBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandleBar = true,
}) {
  final c = context.vellum;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: c.canvas,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    sheetAnimationStyle: const AnimationStyle(
      duration: VellumMotion.sheet,
      reverseDuration: VellumMotion.sheetPop,
      curve: VellumMotion.easeOut,
      reverseCurve: VellumMotion.easeIn,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      final content = builder(ctx);
      if (!showDragHandleBar) return content;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ctx.vellum.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: content),
        ],
      );
    },
  );
}
