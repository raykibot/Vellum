import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 素笺（Vellum）语义色彩体系，精确对齐 Figma 极简纸感设计规范并扩展对称深色模式。
@immutable
class VellumColors extends ThemeExtension<VellumColors> {
  const VellumColors({
    required this.canvas,
    required this.surface,
    required this.card,
    required this.ink,
    required this.inkSecondary,
    required this.muted,
    required this.divider,
    required this.actionBg,
    required this.actionText,
    required this.danger,
  });

  final Color canvas;
  final Color surface;
  final Color card;
  final Color ink;
  final Color inkSecondary;
  final Color muted;
  final Color divider;
  final Color actionBg;
  final Color actionText;
  final Color danger;

  static const light = VellumColors(
    canvas: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F7F7),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF18181B),
    inkSecondary: Color(0xFF66666B),
    muted: Color(0xFF8A8A8E),
    divider: Color(0xFFEBEBEB),
    actionBg: Color(0xFF18181B),
    actionText: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
  );

  static const dark = VellumColors(
    canvas: Color(0xFF0B0B0C),
    surface: Color(0xFF18181B),
    card: Color(0xFF141416),
    ink: Color(0xFFF2F2F3),
    inkSecondary: Color(0xFFA1A1AA),
    muted: Color(0xFF7C7C84),
    divider: Color(0xFF26262A),
    actionBg: Color(0xFFF5F5F7),
    actionText: Color(0xFF0B0B0C),
    danger: Color(0xFFEF4444),
  );

  @override
  VellumColors copyWith({
    Color? canvas,
    Color? surface,
    Color? card,
    Color? ink,
    Color? inkSecondary,
    Color? muted,
    Color? divider,
    Color? actionBg,
    Color? actionText,
    Color? danger,
  }) {
    return VellumColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      muted: muted ?? this.muted,
      divider: divider ?? this.divider,
      actionBg: actionBg ?? this.actionBg,
      actionText: actionText ?? this.actionText,
      danger: danger ?? this.danger,
    );
  }

  @override
  VellumColors lerp(ThemeExtension<VellumColors>? other, double t) {
    if (other is! VellumColors) return this;
    return VellumColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      actionBg: Color.lerp(actionBg, other.actionBg, t)!,
      actionText: Color.lerp(actionText, other.actionText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension VellumColorsContext on BuildContext {
  VellumColors get vellum =>
      Theme.of(this).extension<VellumColors>() ?? VellumColors.light;
}

class VellumTheme {
  static ThemeData light() => _build(Brightness.light, VellumColors.light);

  static ThemeData dark() => _build(Brightness.dark, VellumColors.dark);

  static ThemeData _build(Brightness brightness, VellumColors colors) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.actionBg,
        onPrimary: colors.actionText,
        secondary: colors.surface,
        onSecondary: colors.ink,
        error: colors.danger,
        onError: Colors.white,
        surface: colors.canvas,
        onSurface: colors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.canvas,
                systemNavigationBarIconBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.canvas,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
      ),
      dividerColor: colors.divider,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.ink,
        selectionColor: colors.ink.withValues(alpha: 0.14),
        selectionHandleColor: colors.ink,
      ),
      extensions: [colors],
    );
  }
}
