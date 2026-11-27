import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/widgets/segmented_pill.dart';
import 'package:vellum_app/core/widgets/vellum_dialogs.dart';
import 'package:vellum_app/features/detail/photo_gallery_screen.dart';

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

    testWidgets('showVellumDateRangePicker renders Chinese locale smoothly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VellumTheme.light(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showVellumDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020, 1, 1),
                      lastDate: DateTime(2030, 12, 31),
                      helpText: '按日期筛选',
                    );
                  },
                  child: const Text('打开日历'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开日历'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();

      expect(find.text('按日期筛选'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);
      expect(find.textContaining('年'), findsWidgets);
    });

    testWidgets(
        'showVellumDateRangePicker does not trigger underlying PageRoute secondaryAnimation',
        (tester) async {
      final secondaryValues = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: VellumTheme.light(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        transitionDuration: VellumMotion.pagePush,
                        reverseTransitionDuration: VellumMotion.pagePop,
                        pageBuilder: (ctx, _, __) => Scaffold(
                          body: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                showVellumDateRangePicker(
                                  context: ctx,
                                  firstDate: DateTime(2020, 1, 1),
                                  lastDate: DateTime(2030, 12, 31),
                                  helpText: '选择导出时间区间',
                                );
                              },
                              child: const Text('自定义区间'),
                            ),
                          ),
                        ),
                        transitionsBuilder: (_, animation, secondaryAnimation, child) {
                          return AnimatedBuilder(
                            animation: secondaryAnimation,
                            builder: (_, c) {
                              secondaryValues.add(secondaryAnimation.value);
                              return c!;
                            },
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('进入导出页'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('进入导出页'));
      await tester.pumpAndSettle();

      secondaryValues.clear();
      await tester.tap(find.text('自定义区间'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pumpAndSettle();

      expect(find.text('选择导出时间区间'), findsOneWidget);
      expect(secondaryValues, everyElement(0.0));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();

      expect(find.text('选择导出时间区间'), findsNothing);
      expect(find.text('自定义区间'), findsOneWidget);
      expect(secondaryValues, everyElement(0.0));
    });

    testWidgets('PhotoGalleryScreen route keeps previous route still and fades cleanly',
        (tester) async {
      final route = PhotoGalleryScreen.route(
        images: const ['asset://assets/demo/shoreline.png'],
        initialIndex: 0,
        heroTagPrefix: 'test_img_',
      );
      expect(route, isA<PageRoute<void>>());
      final pageRoute = route as PageRoute<void>;
      expect(pageRoute.opaque, isFalse);
      expect(
        pageRoute.reverseTransitionDuration,
        greaterThanOrEqualTo(const Duration(milliseconds: 360)),
      );
      final dummyPrev = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      expect(pageRoute.canTransitionFrom(dummyPrev), isFalse);
    });

    testWidgets('Dragging over MarkdownBody inside SelectionArea scrolls outer view',
        (tester) async {
      final scrollCtrl = ScrollController();
      final longMarkdown =
          List.generate(30, (i) => '第 $i 段正文内容用于测试长文流畅滚动。\n').join('\n');

      await tester.pumpWidget(
        MaterialApp(
          theme: VellumTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollCtrl,
              child: SelectionArea(
                child: MarkdownBody(
                  data: longMarkdown,
                  selectable: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(scrollCtrl.offset, 0);
      await tester.drag(find.byType(MarkdownBody), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(scrollCtrl.offset, greaterThan(100));
      scrollCtrl.dispose();
    });
  });
}
