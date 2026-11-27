import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';

class SegmentedPillOption<T> {
  const SegmentedPillOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 还原 Figma 的胶囊分段选择器（底槽 #F7F7F7、选中滑块纯白带柔和投影），
/// 并复刻 Web `SegmentedControl` 的物理弹簧连续滑动滑块（stiffness: 440, damping: 34）。
class VellumSegmentedPill<T> extends StatefulWidget {
  const VellumSegmentedPill({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.width,
    this.height = 40,
  });

  final List<SegmentedPillOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double? width;
  final double height;

  @override
  State<VellumSegmentedPill<T>> createState() => _VellumSegmentedPillState<T>();
}

class _VellumSegmentedPillState<T> extends State<VellumSegmentedPill<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  int get _selectedIndex {
    final idx = widget.options.indexWhere((o) => o.value == widget.value);
    return idx < 0 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(
      vsync: this,
      value: _selectedIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant VellumSegmentedPill<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIdx = _selectedIndex.toDouble();
    if ((_ctrl.value - nextIdx).abs() > 0.001) {
      _ctrl.animateWith(
        SpringSimulation(
          VellumMotion.pillSpring,
          _ctrl.value,
          nextIdx,
          _ctrl.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumbColor = isDark ? const Color(0xFF27272B) : c.canvas;
    final count = widget.options.length.clamp(1, 16);

    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (widget.width ?? count * 68.0) - 8;
          final segmentWidth = trackWidth / count;

          return Stack(
            children: [
              // 连续物理弹簧滑动的高亮滑块
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  final clamped = _ctrl.value.clamp(0.0, (count - 1).toDouble());
                  return Transform.translate(
                    offset: Offset(clamped * segmentWidth, 0),
                    child: child,
                  );
                },
                child: RepaintBoundary(
                  child: Container(
                    width: segmentWidth,
                    height: widget.height - 8,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius:
                          BorderRadius.circular((widget.height - 8) / 2),
                      boxShadow: isDark
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                    ),
                  ),
                ),
              ),

              // 标签按钮层
              Row(
                mainAxisSize:
                    widget.width == null ? MainAxisSize.min : MainAxisSize.max,
                children: widget.options.map((opt) {
                  final selected = opt.value == widget.value;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!selected) {
                          HapticFeedback.selectionClick();
                          widget.onChanged(opt.value);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: VellumMotion.fast,
                          curve: VellumMotion.easeOut,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w500 : FontWeight.w400,
                            color: selected ? c.ink : c.muted,
                          ),
                          child: Text(opt.label),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
