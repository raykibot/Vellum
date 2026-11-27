import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/widgets/segmented_pill.dart';

void main() {
  group('VellumSpringCurve', () {
    test('preserves exact 0 and 1 endpoints with smooth trajectory', () {
      final curve = VellumSpringCurve(VellumMotion.modalSpring);
      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);
      expect(curve.transform(0.35), greaterThan(0.5));
      expect(curve.transform(0.8), closeTo(1.0, 0.08));
    });
  });

  group('Motion widgets', () {
    testWidgets('VellumTactile dispatches onTap and settles cleanly',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: VellumTheme.light(),
          home: Scaffold(
            body: Center(
              child: VellumTactile(
                onTap: () => tapped++,
                child: const SizedBox(
                  width: 100,
                  height: 44,
                  child: Text('点击'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('点击'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('VellumSegmentedPill glides between options smoothly',
        (tester) async {
      var selected = 'all';
      await tester.pumpWidget(
        MaterialApp(
          theme: VellumTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: VellumSegmentedPill<String>(
                    width: 210,
                    value: selected,
                    onChanged: (next) => setState(() => selected = next),
                    options: const [
                      SegmentedPillOption(value: 'all', label: '全部'),
                      SegmentedPillOption(value: 'moment', label: '动态'),
                      SegmentedPillOption(value: 'article', label: '长文'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('长文'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(selected, 'article');
    });
  });
}
