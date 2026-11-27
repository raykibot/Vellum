import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地配置与安全凭证存储。
/// - JWT Token / 用户名存放在 Android Keystore 加密存储
/// - 服务地址、主题模式、生物识别开关与锁屏超时存放在 SharedPreferences
class AppStorage {
  AppStorage(this._prefs, [FlutterSecureStorage? secure])
      : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _tokenKey = 'vellum_token';
  static const _expiresAtKey = 'vellum_token_expires_at';
  static const _usernameKey = 'vellum_username';
  static const _apiBaseKey = 'vellum_api_base';
  static const _themeModeKey = 'vellum_theme_mode';
  static const _biometricEnabledKey = 'vellum_biometric_enabled';
  static const _lockTimeoutKey = 'vellum_lock_timeout_seconds';
  static const _demoModeKey = 'vellum_demo_mode';

  static String normalizeApiBase(String raw) {
    return raw.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static String resolveMediaUrl(String url, String baseUrl) {
    if (url.isEmpty ||
        url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('asset://') ||
        url.startsWith('file://')) {
      return url;
    }
    final cleanBase = normalizeApiBase(baseUrl);
    if (cleanBase.isEmpty) return url;
    return url.startsWith('/') ? '$cleanBase$url' : '$cleanBase/$url';
  }

  String getApiBaseUrl() {
    return normalizeApiBase(_prefs.getString(_apiBaseKey) ?? '');
  }

  Future<void> setApiBaseUrl(String raw) async {
    final normalized = normalizeApiBase(raw);
    if (normalized.isEmpty) {
      await _prefs.remove(_apiBaseKey);
    } else {
      await _prefs.setString(_apiBaseKey, normalized);
    }
  }

  ThemeMode getThemeMode() {
    final raw = _prefs.getString(_themeModeKey);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_themeModeKey, value);
  }

  bool isBiometricEnabled() => _prefs.getBool(_biometricEnabledKey) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// 切后台超时锁定时间（秒）：0 = 立即，30 = 30秒，60 = 1分钟，300 = 5分钟
  int getLockTimeoutSeconds() => _prefs.getInt(_lockTimeoutKey) ?? 60;

  Future<void> setLockTimeoutSeconds(int seconds) async {
    await _prefs.setInt(_lockTimeoutKey, seconds);
  }

  bool isDemoMode() => _prefs.getBool(_demoModeKey) ?? false;

  Future<void> setDemoMode(bool value) async {
    await _prefs.setBool(_demoModeKey, value);
  }

  Future<String?> getToken() => _secure.read(key: _tokenKey);

  Future<String?> getExpiresAt() => _secure.read(key: _expiresAtKey);

  Future<String?> getUsername() => _secure.read(key: _usernameKey);

  Future<void> saveSession({
    required String token,
    required String expiresAt,
    required String username,
  }) async {
    await Future.wait([
      _secure.write(key: _tokenKey, value: token),
      _secure.write(key: _expiresAtKey, value: expiresAt),
      _secure.write(key: _usernameKey, value: username),
    ]);
  }

  Future<void> clearSession() async {
    await Future.wait([
      _secure.delete(key: _tokenKey),
      _secure.delete(key: _expiresAtKey),
    ]);
  }

  Future<bool> hasValidSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    final expiresAt = await getExpiresAt();
    if (expiresAt == null || expiresAt.isEmpty) return true;
    final parsed = DateTime.tryParse(expiresAt);
    if (parsed == null) return true;
    return parsed.isAfter(DateTime.now().toUtc());
  }
}
