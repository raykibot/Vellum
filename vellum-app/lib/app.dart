import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/data/providers/app_providers.dart';
import 'package:vellum_app/features/lock/lock_overlay.dart';
import 'package:vellum_app/router/app_router.dart';

class _VellumScrollBehavior extends ScrollBehavior {
  const _VellumScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

/// 应用根组件：管理全局深浅色主题、120Hz 物理滚动、GoRouter 以及切后台超时自动指纹锁屏。
class VellumApp extends ConsumerStatefulWidget {
  const VellumApp({super.key});

  @override
  ConsumerState<VellumApp> createState() => _VellumAppState();
}

class _VellumAppState extends ConsumerState<VellumApp>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = ref.read(authProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (auth.canAccessApp && auth.biometricEnabled) {
        _pausedAt ??= DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null && auth.canAccessApp && auth.biometricEnabled) {
        final elapsed = DateTime.now().difference(pausedAt).inSeconds;
        if (elapsed >= auth.lockTimeoutSeconds) {
          ref.read(authProvider.notifier).lockApp();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    final auth = ref.watch(authProvider);
    final showLock = auth.locked && auth.canAccessApp;

    return MaterialApp.router(
      title: '素笺',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: VellumTheme.light(),
      darkTheme: VellumTheme.dark(),
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: VellumMotion.easeOut,
      scrollBehavior: const _VellumScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            AnimatedSwitcher(
              duration: VellumMotion.pageFade,
              reverseDuration: const Duration(milliseconds: 260),
              switchInCurve: VellumMotion.easeOut,
              switchOutCurve: VellumMotion.easeIn,
              transitionBuilder: (widgetChild, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1.0).animate(anim),
                    child: widgetChild,
                  ),
                );
              },
              child: showLock
                  ? const LockOverlay(key: ValueKey('lock'))
                  : const SizedBox.shrink(key: ValueKey('unlocked')),
            ),
          ],
        );
      },
    );
  }
}
