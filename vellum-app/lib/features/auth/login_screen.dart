import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';
import 'package:vellum_app/data/providers/app_providers.dart';

/// 还原 Figma「8:62 素笺 · 登录」：居中品牌字标 + 极简灰底输入 + 可折叠服务器地址配置 + 全宽胶囊主按钮。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();

  bool _serverExpanded = false;
  bool _submitting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final savedUrl = ref.read(appStorageProvider).getApiBaseUrl();
    if (savedUrl.isNotEmpty) {
      _serverCtrl.text = savedUrl;
      _serverExpanded = true;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final serverUrl = _serverCtrl.text.trim();

    if (serverUrl.isEmpty) {
      setState(() {
        _serverExpanded = true;
        _errorMsg = '请展开并填写服务器地址';
      });
      return;
    }
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = '请输入账号与密码');
      return;
    }

    setState(() {
      _errorMsg = null;
      _submitting = true;
    });

    try {
      await ref.read(authProvider.notifier).login(
            serverUrl: serverUrl,
            username: username,
            password: password,
          );
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _enterDemo() async {
    await ref.read(authProvider.notifier).enterDemoMode();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: VellumEntrance(
                  offsetY: 12,
                  duration: const Duration(milliseconds: 360),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      // Brand header (Figma 8:79)
                      Column(
                        children: [
                          VellumIcon(
                            VellumIcons.notebookLogo48,
                            size: 48,
                            color: c.ink,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '素笺',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 27,
                              height: 40 / 27,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Vellum',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 22 / 13,
                              fontWeight: FontWeight.w500,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 52),

                      // Account & Password inputs (Figma 8:274, 8:276)
                      _buildInput(
                        controller: _usernameCtrl,
                        hint: '账号',
                        colors: c,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      _buildInput(
                        controller: _passwordCtrl,
                        hint: '密码',
                        colors: c,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 30),

                      // Collapsible server URL configuration (Figma 8:278 - 8:283)
                      VellumTactile(
                        pressedScale: 0.985,
                        onTap: () =>
                            setState(() => _serverExpanded = !_serverExpanded),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '服务器地址配置',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 24 / 13,
                                  color: c.muted,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: _serverExpanded ? 0 : 0.5,
                              duration: const Duration(milliseconds: 280),
                              curve: VellumMotion.easeOut,
                              child: VellumIcon(
                                VellumIcons.chevronUp,
                                size: 20,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      VellumCollapsible(
                        expanded: _serverExpanded,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildInput(
                            controller: _serverCtrl,
                            hint: 'https://vellum.example.com',
                            colors: c,
                            height: 52,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ),

                      VellumCollapsible(
                        expanded: _errorMsg != null,
                        duration: VellumMotion.fast,
                        child: _errorMsg != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  _errorMsg!,
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontSize: 12.5, color: c.danger),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 32),

                      // Pill login button (Figma 8:284)
                      VellumButton(
                        width: double.infinity,
                        height: 52,
                        loading: _submitting,
                        onPressed: _submitting ? null : _submit,
                        backgroundColor: c.actionBg,
                        foregroundColor: c.actionText,
                        borderRadius: BorderRadius.circular(26),
                        child: const Text(
                          '登录',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: VellumTactile(
                          pressedScale: 0.95,
                          enabled: !_submitting,
                          onTap: _submitting ? null : _enterDemo,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              '预览示例界面',
                              style: TextStyle(fontSize: 13, color: c.muted),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required VellumColors colors,
    double height = 56,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: colors.ink,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: colors.muted,
          ),
        ),
      ),
    );
  }
}
