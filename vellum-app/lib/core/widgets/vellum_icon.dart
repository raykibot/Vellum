import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';

/// 统一渲染 Figma 导出的 SVG 线性图标，自动适配浅色/深色主题着色。
class VellumIcon extends StatelessWidget {
  const VellumIcon(
    this.assetPath, {
    super.key,
    this.size = 24,
    this.color,
  });

  final String assetPath;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.vellum.ink;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SvgPicture.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// 素笺图标资产路径常量。
class VellumIcons {
  static const notebookMark = 'assets/icons/notebook_mark.svg';
  static const notebookLogo40 = 'assets/icons/notebook_logo_40.svg';
  static const notebookLogo48 = 'assets/icons/notebook_logo_48.svg';
  static const search = 'assets/icons/search.svg';
  static const export = 'assets/icons/export.svg';
  static const settings = 'assets/icons/settings.svg';
  static const calendarFilter = 'assets/icons/calendar_filter.svg';
  static const plus = 'assets/icons/plus.svg';
  static const back = 'assets/icons/back.svg';
  static const moreVertical = 'assets/icons/more_vertical.svg';
  static const closeSm = 'assets/icons/close_sm.svg';
  static const chooseImages = 'assets/icons/choose_images.svg';
  static const importDoc = 'assets/icons/import_doc.svg';
  static const location = 'assets/icons/location.svg';
  static const formatMd = 'assets/icons/format_md.svg';
  static const formatZip = 'assets/icons/format_zip.svg';
  static const radioUnselected = 'assets/icons/radio_unselected.svg';
  static const radioSelected = 'assets/icons/radio_selected.svg';
  static const chevronUp = 'assets/icons/chevron_up.svg';
  static const fingerprint = 'assets/icons/fingerprint.svg';
}
