import 'package:flutter/material.dart';
import 'package:vellum_app/core/location/city_locator.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/widgets/vellum_dialogs.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';

/// 城市选择弹窗：用于自动定位失败时引导用户搜索选择城市或选择留空。
class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({
    super.key,
    this.currentCity,
    this.locationFailed = false,
  });

  final String? currentCity;
  final bool locationFailed;

  /// 返回选中的城市名；返回空字符串表示显式留空；返回 null 表示取消关闭。
  static Future<String?> show(
    BuildContext context, {
    String? currentCity,
    bool locationFailed = false,
  }) {
    return showVellumBottomSheet<String>(
      context: context,
      builder: (_) => CityPickerSheet(
        currentCity: currentCity,
        locationFailed: locationFailed,
      ),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _cities = const [];

  @override
  void initState() {
    super.initState();
    _filter('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _filter(String q) async {
    final result = await CityLocator.searchCities(q);
    if (mounted) {
      setState(() => _cities = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            18,
            24,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.locationFailed ? '未能自动获取当前城市' : '选择所在城市',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        if (widget.locationFailed) ...[
                          const SizedBox(height: 4),
                          Text(
                            '可手动搜索选择城市，或留空不记录位置',
                            style: TextStyle(fontSize: 12, color: c.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  VellumTactile(
                    onTap: () => Navigator.of(context).pop(''),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        '留空',
                        style: TextStyle(fontSize: 13.5, color: c.muted),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    VellumIcon(VellumIcons.search, size: 16, color: c.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _filter,
                        style: TextStyle(fontSize: 14, color: c.ink),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: '搜索城市名（如：深圳、杭州）',
                          hintStyle: TextStyle(fontSize: 13.5, color: c.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: _cities.length,
                  separatorBuilder: (_, __) =>
                      Container(height: 1, color: c.divider),
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    final selected = city == widget.currentCity;
                    return VellumTactile(
                      pressedScale: 0.985,
                      onTap: () => Navigator.of(context).pop(city),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          city,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: c.ink,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check, size: 18, color: c.ink)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
