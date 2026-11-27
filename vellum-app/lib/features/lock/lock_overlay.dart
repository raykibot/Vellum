import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/widgets/vellum_dialogs.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';
import 'package:vellum_app/data/providers/app_providers.dart';

/// 还原 Figma「8:81 素笺 · 指纹解锁」：全屏安全遮罩层，解锁后原页面上下文与编辑草稿无损保留。
class LockOverlay extends ConsumerStatefulWidget {
  const LockOverlay({super.key});

  @override
  ConsumerState<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends ConsumerState<LockOverlay> {
  final _localAuth = LocalAuthentication();
  bool _authenticating = false;
  String _promptText = '验证指纹以解锁';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating || !mounted) return;
    setState(() {
      _authenticating = true;
      _promptText = '验证指纹以解锁';
    });

    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported && !canCheck) {
        if (mounted) {
          setState(() => _promptText = '当前设备未配置生物识别，请使用密码验证');
        }
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: '验证身份以打开素笺',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) {
        ref.read(authProvider.notifier).unlockApp();
      } else if (mounted) {
        setState(() => _promptText = '轻触指纹图标重试');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _promptText = '生物识别验证失败，请点击重试或使用密码');
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _openPasswordFallback() async {
    final ctrl = TextEditingController();
    String? error;
    var submitting = false;

    await showVellumBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        final c = sheetCtx.vellum;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '密码验证',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: ctrl,
                      obscureText: true,
                      autofocus: true,
                      style: TextStyle(fontSize: 14, color: c.ink),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: '输入登录密码',
                        hintStyle: TextStyle(fontSize: 14, color: c.muted),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(fontSize: 12.5, color: c.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  VellumButton(
                    width: double.infinity,
                    height: 48,
                    loading: submitting,
                    backgroundColor: c.actionBg,
                    foregroundColor: c.actionText,
                    borderRadius: BorderRadius.circular(24),
                    onPressed: submitting
                        ? null
                        : () async {
                            setSheetState(() {
                              submitting = true;
                              error = null;
                            });
                            try {
                              await ref
                                  .read(authProvider.notifier)
                                  .verifyPasswordToUnlock(ctrl.text);
                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                            } catch (e) {
                              setSheetState(() {
                                submitting = false;
                                error = e.toString();
                              });
                            }
                          },
                    child: const Text(
                      '解锁',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;

    return PopScope(
      canPop: false,
      child: Material(
        color: c.canvas,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: VellumEntrance(
              offsetY: 10,
              duration: const Duration(milliseconds: 320),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  // Brand header (Figma 8:98)
                  Column(
                    children: [
                      VellumIcon(
                        VellumIcons.notebookLogo40,
                        size: 40,
                        color: c.ink,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Vellum',
                        style: TextStyle(
                          fontSize: 18,
                          height: 28 / 18,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Biometric verification (Figma 8:99)
                  VellumTactile(
                    pressedScale: 0.92,
                    onTap: _authenticate,
                    child: Column(
                      children: [
                        VellumPulse(
                          active: _authenticating,
                          minOpacity: 0.48,
                          duration: const Duration(milliseconds: 900),
                          child: VellumIcon(
                            VellumIcons.fingerprint,
                            size: 72,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AnimatedSwitcher(
                          duration: VellumMotion.fast,
                          switchInCurve: VellumMotion.easeOut,
                          child: Text(
                            _promptText,
                            key: ValueKey(_promptText),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 26 / 14,
                              color: c.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Password fallback (Figma 8:100)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: VellumTactile(
                      pressedScale: 0.94,
                      onTap: _openPasswordFallback,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          '使用密码验证',
                          style: TextStyle(fontSize: 13, color: c.muted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
