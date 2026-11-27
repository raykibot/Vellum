import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';
import 'package:vellum_app/core/utils/formatters.dart';
import 'package:vellum_app/core/widgets/vellum_icon.dart';
import 'package:vellum_app/data/models/models.dart';
import 'package:vellum_app/data/providers/app_providers.dart';

/// 沿用 Figma 素笺纸感设计规范（#FFFFFF + #F7F7F7 + #18181B + #EBEBEB）打造的设置页：
/// 包含指纹解锁开关与切后台自动锁屏超时、外观主题、服务器地址、离线待补发队列管理与退出登录。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serverCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();
  bool _serverSaved = false;
  bool _syncing = false;

  static const _timeoutOptions = [
    (seconds: 0, label: '立即'),
    (seconds: 30, label: '30 秒'),
    (seconds: 60, label: '1 分钟'),
    (seconds: 300, label: '5 分钟'),
  ];

  @override
  void initState() {
    super.initState();
    _serverCtrl.text = ref.read(appStorageProvider).getApiBaseUrl();
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleBiometric(bool next) async {
    if (!next) {
      await ref.read(authProvider.notifier).setBiometricEnabled(false);
      return;
    }

    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported && !canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前设备未启用系统生物识别')),
          );
        }
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: '验证身份以开启指纹解锁',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) {
        await ref.read(authProvider.notifier).setBiometricEnabled(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('验证失败：$e')),
        );
      }
    }
  }

  Future<void> _saveServerUrl() async {
    await ref.read(authProvider.notifier).updateServerUrl(_serverCtrl.text);
    if (!mounted) return;
    setState(() => _serverSaved = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _serverSaved = false);
    });
  }

  Future<void> _retrySync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await ref.read(timelineProvider.notifier).syncPendingPosts();
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    final auth = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final pendingPosts = ref.watch(timelineProvider).pendingPosts;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    VellumTactile(
                      pressedScale: 0.88,
                      onTap: () => context.pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: VellumIcon(
                          VellumIcons.back,
                          size: 24,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  // 1. 安全与锁屏
                  const _SectionLabel(title: '安全与锁屏'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            VellumIcon(
                              VellumIcons.fingerprint,
                              size: 22,
                              color: c.ink,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '指纹解锁',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '打开应用或从后台返回时验证身份',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: auth.biometricEnabled,
                              onChanged: _toggleBiometric,
                              activeThumbColor: c.actionText,
                              activeTrackColor: c.actionBg,
                            ),
                          ],
                        ),
                        VellumCollapsible(
                          expanded: auth.biometricEnabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(vertical: 14),
                                color: c.divider,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '切后台自动锁屏',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.inkSecondary,
                                    ),
                                  ),
                                  VellumTactile(
                                    pressedScale: 0.94,
                                    onTap: () => ref
                                        .read(authProvider.notifier)
                                        .lockApp(),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        '立即测试锁屏',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: c.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: _timeoutOptions.map((opt) {
                                  final selected =
                                      auth.lockTimeoutSeconds == opt.seconds;
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: opt == _timeoutOptions.last
                                            ? 0
                                            : 8,
                                      ),
                                      child: VellumTactile(
                                        pressedScale: 0.95,
                                        onTap: () => ref
                                            .read(authProvider.notifier)
                                            .setLockTimeoutSeconds(opt.seconds),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 240),
                                          curve: VellumMotion.easeOut,
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? c.actionBg
                                                : c.canvas,
                                            borderRadius:
                                                BorderRadius.circular(17),
                                            border: selected
                                                ? null
                                                : Border.all(color: c.divider),
                                          ),
                                          child: AnimatedDefaultTextStyle(
                                            duration: VellumMotion.fast,
                                            curve: VellumMotion.easeOut,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: selected
                                                  ? c.actionText
                                                  : c.inkSecondary,
                                            ),
                                            child: Text(opt.label),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 2. 外观
                  const _SectionLabel(title: '外观'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ThemeOptionCard(
                          label: '浅色',
                          mode: ThemeMode.light,
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.light),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ThemeOptionCard(
                          label: '深色',
                          mode: ThemeMode.dark,
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.dark),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ThemeOptionCard(
                          label: '跟随系统',
                          mode: ThemeMode.system,
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.system),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 3. 服务器地址
                  Row(
                    children: [
                      const _SectionLabel(title: '服务器地址'),
                      const Spacer(),
                      Text(
                        auth.demoMode ? '示例预览模式' : '在线账号：${auth.username ?? ''}',
                        style: TextStyle(fontSize: 11.5, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _serverCtrl,
                            keyboardType: TextInputType.url,
                            style: TextStyle(fontSize: 13, color: c.ink),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: 'https://vellum.example.com',
                              hintStyle:
                                  TextStyle(fontSize: 13, color: c.muted),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      VellumButton(
                        height: 48,
                        onPressed: _saveServerUrl,
                        backgroundColor: c.actionBg,
                        foregroundColor: c.actionText,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedSwitcher(
                          duration: VellumMotion.fast,
                          switchInCurve: VellumMotion.easeOut,
                          child: Text(
                            _serverSaved ? '已保存' : '保存',
                            key: ValueKey(_serverSaved),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 4. 本地待补发队列
                  Row(
                    children: [
                      _SectionLabel(
                        title: '本地待补发记录（${pendingPosts.length}）',
                      ),
                      const Spacer(),
                      if (pendingPosts.isNotEmpty)
                        VellumTactile(
                          pressedScale: 0.94,
                          enabled: !_syncing,
                          onTap: _syncing ? null : _retrySync,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 4,
                            ),
                            child: Text(
                              _syncing ? '同步中...' : '全部重试',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (pendingPosts.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '所有记录均已同步至服务器',
                        style: TextStyle(fontSize: 13, color: c.muted),
                      ),
                    )
                  else
                    Column(
                      children: pendingPosts.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title?.isNotEmpty == true
                                          ? item.title!
                                          : (item.content.isNotEmpty
                                              ? item.content
                                              : '纯图片动态 (${item.images.length} 张)'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${formatDotDate(item.recordTime)} ${formatTime(item.recordTime)} · ${_statusLabel(item)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: item.status == SyncStatus.failed
                                            ? c.danger
                                            : c.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              VellumTactile(
                                pressedScale: 0.85,
                                onTap: () => ref
                                    .read(timelineProvider.notifier)
                                    .discardPendingPost(item.localId),
                                child: Tooltip(
                                  message: '移除',
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: VellumIcon(
                                      VellumIcons.closeSm,
                                      size: 14,
                                      color: c.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 36),

                  // 5. 退出登录
                  VellumButton(
                    width: double.infinity,
                    height: 50,
                    backgroundColor: Colors.transparent,
                    foregroundColor: c.danger,
                    borderColor: c.divider,
                    borderRadius: BorderRadius.circular(25),
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                    child: Text(
                      auth.demoMode ? '退出示例预览' : '退出登录',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(PendingPost item) {
    switch (item.status) {
      case SyncStatus.pending:
        return '等待同步';
      case SyncStatus.uploading:
        return '正在同步...';
      case SyncStatus.failed:
        return item.lastError ?? '同步失败';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: context.vellum.ink,
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    return VellumTactile(
      pressedScale: 0.975,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: VellumMotion.easeOut,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.ink : c.divider,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: c.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (mode == ThemeMode.light) ...[
                      Expanded(
                        flex: 1,
                        child: Container(color: const Color(0xFFF5F5F7)),
                      ),
                      Expanded(flex: 2, child: Container(color: Colors.white)),
                    ] else if (mode == ThemeMode.dark) ...[
                      Expanded(
                        flex: 1,
                        child: Container(color: const Color(0xFF141416)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(color: const Color(0xFF0B0B0C)),
                      ),
                    ] else ...[
                      Expanded(child: Container(color: Colors.white)),
                      Expanded(
                        child: Container(color: const Color(0xFF0B0B0C)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? c.ink : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
