import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/data/models/models.dart';
import 'package:vellum_app/data/providers/app_providers.dart';
import 'package:vellum_app/features/auth/login_screen.dart';
import 'package:vellum_app/features/compose/compose_screen.dart';
import 'package:vellum_app/features/detail/post_detail_screen.dart';
import 'package:vellum_app/features/export/export_screen.dart';
import 'package:vellum_app/features/settings/settings_screen.dart';
import 'package:vellum_app/features/timeline/home_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

CustomTransitionPage<void> _vellumSlidePage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: VellumMotion.pagePush,
    reverseTransitionDuration: VellumMotion.pagePop,
    child: RepaintBoundary(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      final isForward = animation.status != AnimationStatus.reverse;
      final enterCurve = CurvedAnimation(
        parent: animation,
        curve: isForward ? VellumMotion.easeOut : VellumMotion.easeIn,
      );
      final exitCurve = CurvedAnimation(
        parent: secondaryAnimation,
        curve: VellumMotion.easeOut,
      );

      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(enterCurve);

      final parallaxOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.22, 0.0),
      ).animate(exitCurve);

      final dimOut = Tween<double>(begin: 0.0, end: 0.06).animate(exitCurve);

      return SlideTransition(
        position: parallaxOut,
        child: SlideTransition(
          position: slideIn,
          child: AnimatedBuilder(
            animation: secondaryAnimation,
            builder: (ctx, c) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: animation.value > 0.01 && animation.value < 0.99
                      ? const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 24,
                            offset: Offset(-6, 0),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    c!,
                    if (dimOut.value > 0.001)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: dimOut.value),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            child: pageChild,
          ),
        ),
      );
    },
  );
}

CustomTransitionPage<void> _vellumModalPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: VellumMotion.pageModal,
    reverseTransitionDuration: VellumMotion.pageModalPop,
    child: RepaintBoundary(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      final isForward = animation.status != AnimationStatus.reverse;
      final curve = CurvedAnimation(
        parent: animation,
        curve: isForward ? VellumMotion.easeOut : VellumMotion.easeIn,
      );
      final slideUp = Tween<Offset>(
        begin: const Offset(0.0, 0.14),
        end: Offset.zero,
      ).animate(curve);
      final scaleIn = Tween<double>(begin: 0.965, end: 1.0).animate(curve);

      final exitCurve = CurvedAnimation(
        parent: secondaryAnimation,
        curve: VellumMotion.easeOut,
      );
      final dimOut = Tween<double>(begin: 0.0, end: 0.06).animate(exitCurve);

      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: slideUp,
          child: ScaleTransition(
            scale: scaleIn,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                pageChild,
                if (dimOut.value > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: dimOut.value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

CustomTransitionPage<void> _vellumFadePage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: VellumMotion.pageFade,
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: RepaintBoundary(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      final isForward = animation.status != AnimationStatus.reverse;
      final curve = CurvedAnimation(
        parent: animation,
        curve: isForward ? VellumMotion.easeOut : VellumMotion.easeIn,
      );
      final slideIn = Tween<Offset>(
        begin: const Offset(0.0, 0.025),
        end: Offset.zero,
      ).animate(curve);

      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: slideIn,
          child: pageChild,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (!auth.initialized) return null;

      final isLogin = state.matchedLocation == '/login';
      if (!auth.canAccessApp) {
        return isLogin ? null : '/login';
      }
      if (isLogin) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _vellumFadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _vellumFadePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/detail/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra is PostItem ? state.extra as PostItem : null;
          return _vellumSlidePage(
            state,
            PostDetailScreen(postId: id, initialPost: extra),
          );
        },
      ),
      GoRoute(
        path: '/compose',
        pageBuilder: (context, state) =>
            _vellumModalPage(state, const ComposeScreen()),
      ),
      GoRoute(
        path: '/export',
        pageBuilder: (context, state) =>
            _vellumSlidePage(state, const ExportScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _vellumSlidePage(state, const SettingsScreen()),
      ),
    ],
  );
});
