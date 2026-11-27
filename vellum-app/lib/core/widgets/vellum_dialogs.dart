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
      final fadeCurve = CurvedAnimation(
        parent: animation,
        curve: VellumMotion.easeOut,
        reverseCurve: VellumMotion.easeOutReverse,
      );
      final motionCurve = CurvedAnimation(
        parent: animation,
        curve: VellumMotion.modalCurve,
        reverseCurve: VellumMotion.easeOutReverse,
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
      reverseCurve: VellumMotion.easeOutReverse,
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

/// 统一的中文化日期区间选择器弹出层：保持原生日历内部交互，仅优化进入/退出的 120Hz 丝滑转场与素笺极简黑白主题。
Future<DateTimeRange?> showVellumDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  String helpText = '选择日期区间',
  String saveText = '确定',
  String cancelText = '取消',
}) {
  return Navigator.of(context, rootNavigator: true).push<DateTimeRange>(
    _VellumPopupRoute<DateTimeRange>(
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final c = ctx.vellum;
        final baseTheme = Theme.of(ctx);
        return Localizations.override(
          context: ctx,
          locale: const Locale('zh', 'CN'),
          child: Theme(
            data: baseTheme.copyWith(
              colorScheme: baseTheme.colorScheme.copyWith(
                primary: c.actionBg,
                onPrimary: c.actionText,
                surface: c.canvas,
                onSurface: c.ink,
              ),
              datePickerTheme: DatePickerThemeData(
                backgroundColor: c.canvas,
                surfaceTintColor: Colors.transparent,
                headerBackgroundColor: c.canvas,
                headerForegroundColor: c.ink,
                rangePickerBackgroundColor: c.canvas,
                rangePickerSurfaceTintColor: Colors.transparent,
                rangePickerElevation: 0,
                rangePickerHeaderBackgroundColor: c.canvas,
                rangePickerHeaderForegroundColor: c.ink,
                rangeSelectionBackgroundColor: c.ink.withValues(alpha: 0.08),
              ),
            ),
            child: DateRangePickerDialog(
              firstDate: firstDate,
              lastDate: lastDate,
              initialDateRange: initialDateRange,
              helpText: helpText,
              saveText: saveText,
              cancelText: cancelText,
              confirmText: saveText,
              fieldStartLabelText: '开始日期',
              fieldEndLabelText: '结束日期',
              errorFormatText: '日期格式无效',
              errorInvalidText: '超出可选范围',
              errorInvalidRangeText: '结束日期不能早于开始日期',
            ),
          ),
        );
      },
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        final motionCurve = CurvedAnimation(
          parent: animation,
          curve: VellumMotion.easeOut,
          reverseCurve: VellumMotion.easeOutReverse,
        );
        final fadeCurve = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.78, curve: VellumMotion.easeOut),
          reverseCurve: VellumMotion.easeOutReverse,
        );

        final slideUp = Tween<Offset>(
          begin: const Offset(0.0, 0.12),
          end: Offset.zero,
        ).animate(motionCurve);
        final scaleIn = Tween<double>(
          begin: 0.96,
          end: 1.0,
        ).animate(motionCurve);

        return RepaintBoundary(
          child: FadeTransition(
            opacity: fadeCurve,
            child: SlideTransition(
              position: slideUp,
              child: ScaleTransition(
                scale: scaleIn,
                child: child,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _VellumPopupRoute<T> extends PopupRoute<T> {
  _VellumPopupRoute({
    required this.pageBuilder,
    required this.transitionsBuilder,
    required Duration transitionDuration,
    required Duration reverseTransitionDuration,
    Color? barrierColor,
    bool barrierDismissible = true,
    String? barrierLabel,
  })  : _transitionDuration = transitionDuration,
        _reverseTransitionDuration = reverseTransitionDuration,
        _barrierColor = barrierColor,
        _barrierDismissible = barrierDismissible,
        _barrierLabel = barrierLabel;

  final RoutePageBuilder pageBuilder;
  final RouteTransitionsBuilder transitionsBuilder;
  final Duration _transitionDuration;
  final Duration _reverseTransitionDuration;
  final Color? _barrierColor;
  final bool _barrierDismissible;
  final String? _barrierLabel;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: pageBuilder(context, animation, secondaryAnimation),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return transitionsBuilder(context, animation, secondaryAnimation, child);
  }
}
