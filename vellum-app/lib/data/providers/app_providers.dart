import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vellum_app/core/db/vellum_db.dart';
import 'package:vellum_app/core/media/media_helper.dart';
import 'package:vellum_app/core/network/api_client.dart';
import 'package:vellum_app/core/storage/app_storage.dart';
import 'package:vellum_app/data/api/vellum_api.dart';
import 'package:vellum_app/data/models/models.dart';
import 'package:vellum_app/data/repositories/outbox_sync_service.dart';

const _uuid = Uuid();

final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('appStorageProvider must be overridden in main');
});

final vellumDbProvider = Provider<VellumDb>((ref) {
  throw UnimplementedError('vellumDbProvider must be overridden in main');
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(appStorageProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._storage) : super(_storage.getThemeMode());

  final AppStorage _storage;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.setThemeMode(mode);
  }
}

class AuthState {
  const AuthState({
    required this.initialized,
    required this.authenticated,
    required this.demoMode,
    required this.locked,
    required this.biometricEnabled,
    required this.lockTimeoutSeconds,
    this.apiBaseUrl = '',
    this.username,
    this.token,
  });

  final bool initialized;
  final bool authenticated;
  final bool demoMode;
  final bool locked;
  final bool biometricEnabled;
  final int lockTimeoutSeconds;
  final String apiBaseUrl;
  final String? username;
  final String? token;

  bool get canAccessApp => authenticated || demoMode;

  AuthState copyWith({
    bool? initialized,
    bool? authenticated,
    bool? demoMode,
    bool? locked,
    bool? biometricEnabled,
    int? lockTimeoutSeconds,
    String? apiBaseUrl,
    String? username,
    String? token,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      authenticated: authenticated ?? this.authenticated,
      demoMode: demoMode ?? this.demoMode,
      locked: locked ?? this.locked,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lockTimeoutSeconds: lockTimeoutSeconds ?? this.lockTimeoutSeconds,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      username: username ?? this.username,
      token: token ?? this.token,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref)
      : super(
          const AuthState(
            initialized: false,
            authenticated: false,
            demoMode: false,
            locked: false,
            biometricEnabled: false,
            lockTimeoutSeconds: 60,
          ),
        );

  final Ref _ref;

  AppStorage get _storage => _ref.read(appStorageProvider);

  Future<void> bootstrap() async {
    final valid = await _storage.hasValidSession();
    final demo = _storage.isDemoMode();
    final bioEnabled = _storage.isBiometricEnabled();
    final timeout = _storage.getLockTimeoutSeconds();
    final baseUrl = _storage.getApiBaseUrl();
    final token = valid ? await _storage.getToken() : null;
    final username = await _storage.getUsername();

    state = AuthState(
      initialized: true,
      authenticated: valid,
      demoMode: !valid && demo,
      locked: (valid || demo) && bioEnabled,
      biometricEnabled: bioEnabled,
      lockTimeoutSeconds: timeout,
      apiBaseUrl: baseUrl,
      username: username,
      token: token,
    );
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    await _storage.setApiBaseUrl(serverUrl);
    await _storage.setDemoMode(false);
    final api = _ref.read(vellumApiProvider);
    final resp = await api.login(username: username, password: password);
    await _storage.saveSession(
      token: resp.token,
      expiresAt: resp.expiresAt,
      username: username,
    );
    state = state.copyWith(
      authenticated: true,
      demoMode: false,
      locked: false,
      apiBaseUrl: _storage.getApiBaseUrl(),
      username: username,
      token: resp.token,
    );
  }

  Future<void> enterDemoMode() async {
    await _storage.setDemoMode(true);
    state = state.copyWith(
      authenticated: false,
      demoMode: true,
      locked: false,
      username: '示例用户',
      token: null,
    );
  }

  Future<void> updateServerUrl(String url) async {
    await _storage.setApiBaseUrl(url);
    state = state.copyWith(apiBaseUrl: _storage.getApiBaseUrl());
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.setBiometricEnabled(enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setLockTimeoutSeconds(int seconds) async {
    await _storage.setLockTimeoutSeconds(seconds);
    state = state.copyWith(lockTimeoutSeconds: seconds);
  }

  void lockApp() {
    if (state.canAccessApp && state.biometricEnabled) {
      state = state.copyWith(locked: true);
    }
  }

  void unlockApp() {
    state = state.copyWith(locked: false);
  }

  Future<void> verifyPasswordToUnlock(String password) async {
    if (state.demoMode) {
      if (password.trim().isEmpty) {
        throw ApiException(400, '请输入任意非空密码（示例模式）');
      }
      unlockApp();
      return;
    }
    final user = state.username;
    if (user == null || user.isEmpty) {
      throw ApiException(401, '无法获取当前账号，请重新登录');
    }
    final api = _ref.read(vellumApiProvider);
    final resp = await api.login(username: user, password: password);
    await _storage.saveSession(
      token: resp.token,
      expiresAt: resp.expiresAt,
      username: user,
    );
    state = state.copyWith(
      authenticated: true,
      locked: false,
      token: resp.token,
    );
  }

  Future<void> handleUnauthorized() async {
    if (!state.authenticated) return;
    await _storage.clearSession();
    state = state.copyWith(
      authenticated: false,
      locked: false,
      token: null,
    );
  }

  Future<void> logout() async {
    await _storage.clearSession();
    await _storage.setDemoMode(false);
    await _ref.read(vellumDbProvider).clearCachedPosts();
    state = state.copyWith(
      authenticated: false,
      demoMode: false,
      locked: false,
      token: null,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    storage: ref.watch(appStorageProvider),
    onUnauthorized: () {
      unawaited(ref.read(authProvider.notifier).handleUnauthorized());
    },
  );
});

final vellumApiProvider = Provider<VellumApi>((ref) {
  return VellumApi(ref.watch(apiClientProvider));
});

final outboxSyncServiceProvider = Provider<OutboxSyncService>((ref) {
  return OutboxSyncService(
    db: ref.watch(vellumDbProvider),
    api: ref.watch(vellumApiProvider),
  );
});

class TimelineState {
  const TimelineState({
    this.remotePosts = const [],
    this.pendingPosts = const [],
    this.filter = PostFilterType.all,
    this.keyword = '',
    this.startDate,
    this.endDate,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursorTime,
    this.nextCursorId,
    this.errorMessage,
    this.offlineBanner = false,
  });

  final List<PostItem> remotePosts;
  final List<PendingPost> pendingPosts;
  final PostFilterType filter;
  final String keyword;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursorTime;
  final String? nextCursorId;
  final String? errorMessage;
  final bool offlineBanner;

  List<PostItem> get visiblePosts {
    final pendingMapped = pendingPosts.map((p) => p.toTimelinePostItem());
    final combined = <PostItem>[...pendingMapped, ...remotePosts];
    final q = keyword.trim().toLowerCase();

    final filtered = combined.where((item) {
      if (filter != PostFilterType.all &&
          item.type.apiValue != filter.apiValue) {
        return false;
      }
      if (q.isNotEmpty) {
        final inTitle = (item.title ?? '').toLowerCase().contains(q);
        final inBody = item.content.toLowerCase().contains(q);
        final inCity = (item.locationCity ?? '').toLowerCase().contains(q);
        if (!inTitle && !inBody && !inCity) return false;
      }
      if (startDate != null) {
        final start =
            DateTime(startDate!.year, startDate!.month, startDate!.day);
        if (item.recordTime.toLocal().isBefore(start)) return false;
      }
      if (endDate != null) {
        final endExclusive =
            DateTime(endDate!.year, endDate!.month, endDate!.day + 1);
        if (!item.recordTime.toLocal().isBefore(endExclusive)) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => b.recordTime.compareTo(a.recordTime));
    return filtered;
  }

  TimelineState copyWith({
    List<PostItem>? remotePosts,
    List<PendingPost>? pendingPosts,
    PostFilterType? filter,
    String? keyword,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursorTime,
    bool clearNextCursor = false,
    String? nextCursorId,
    String? errorMessage,
    bool clearError = false,
    bool? offlineBanner,
  }) {
    return TimelineState(
      remotePosts: remotePosts ?? this.remotePosts,
      pendingPosts: pendingPosts ?? this.pendingPosts,
      filter: filter ?? this.filter,
      keyword: keyword ?? this.keyword,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursorTime:
          clearNextCursor ? null : (nextCursorTime ?? this.nextCursorTime),
      nextCursorId:
          clearNextCursor ? null : (nextCursorId ?? this.nextCursorId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      offlineBanner: offlineBanner ?? this.offlineBanner,
    );
  }
}

final timelineProvider =
    StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier(ref);
});

class TimelineNotifier extends StateNotifier<TimelineState> {
  TimelineNotifier(this._ref) : super(const TimelineState()) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online =
          results.any((r) => r != ConnectivityResult.none);
      if (online &&
          _ref.read(authProvider).authenticated &&
          state.pendingPosts.isNotEmpty) {
        unawaited(syncPendingPosts());
      }
    });
  }

  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  VellumDb get _db => _ref.read(vellumDbProvider);
  VellumApi get _api => _ref.read(vellumApiProvider);

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> loadInitial({bool forceRemote = true}) async {
    final auth = _ref.read(authProvider);
    if (!auth.canAccessApp) return;

    if (auth.demoMode) {
      final current = state.remotePosts.isEmpty
          ? DemoSeedData.initialPosts()
          : state.remotePosts;
      state = state.copyWith(
        remotePosts: current,
        pendingPosts: const [],
        isLoading: false,
        hasMore: false,
        offlineBanner: false,
        clearNextCursor: true,
        clearError: true,
      );
      return;
    }

    final pending = await _db.getPendingPosts();
    final cached = await _db.queryCachedPosts(filter: state.filter);
    state = state.copyWith(
      remotePosts: cached,
      pendingPosts: pending,
      isLoading: cached.isEmpty,
      clearError: true,
    );

    if (!forceRemote) return;
    await refresh();
  }

  Future<void> refresh() async {
    final auth = _ref.read(authProvider);
    if (!auth.canAccessApp) return;
    if (auth.demoMode) {
      await loadInitial();
      return;
    }

    state = state.copyWith(isLoading: state.remotePosts.isEmpty, clearError: true);
    try {
      final page = await _api.fetchPosts(size: 15, type: state.filter);
      await _db.upsertCachedPosts(page.items);
      final pending = await _db.getPendingPosts();
      state = state.copyWith(
        remotePosts: page.items,
        pendingPosts: pending,
        isLoading: false,
        hasMore: page.hasMore,
        nextCursorTime: page.nextCursorTime,
        nextCursorId: page.nextCursorId,
        offlineBanner: false,
      );
      if (pending.isNotEmpty) {
        unawaited(syncPendingPosts());
      }
    } on ApiException catch (e) {
      final cached = await _db.queryCachedPosts(filter: state.filter);
      state = state.copyWith(
        remotePosts: cached,
        isLoading: false,
        offlineBanner: e.code == 0,
        errorMessage: e.code == 0 ? null : e.message,
      );
    }
  }

  Future<void> loadMore() async {
    final auth = _ref.read(authProvider);
    if (auth.demoMode ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.nextCursorTime == null ||
        state.nextCursorId == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _api.fetchPosts(
        size: 15,
        type: state.filter,
        cursorTime: state.nextCursorTime,
        cursorId: state.nextCursorId,
      );
      await _db.upsertCachedPosts(page.items);
      final existingIds = state.remotePosts.map((e) => e.id).toSet();
      final merged = [
        ...state.remotePosts,
        ...page.items.where((e) => !existingIds.contains(e.id)),
      ];
      state = state.copyWith(
        remotePosts: merged,
        isLoadingMore: false,
        hasMore: page.hasMore,
        nextCursorTime: page.nextCursorTime,
        nextCursorId: page.nextCursorId,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> setFilter(PostFilterType filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(
      filter: filter,
      clearNextCursor: true,
      hasMore: false,
    );
    await loadInitial();
  }

  void setKeyword(String value) {
    state = state.copyWith(keyword: value);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(
      startDate: start,
      clearStartDate: start == null,
      endDate: end,
      clearEndDate: end == null,
    );
  }

  Future<PostItem> loadPostDetail(PostItem item) async {
    if (item.isPending || _ref.read(authProvider).demoMode) {
      return item;
    }
    if (!item.contentTruncated) {
      return item;
    }
    try {
      final full = await _api.fetchPostDetail(item.id);
      await _db.updateCachedFullContent(full);
      state = state.copyWith(
        remotePosts: state.remotePosts
            .map((e) => e.id == full.id ? full : e)
            .toList(),
      );
      return full;
    } catch (_) {
      final cached = await _db.getCachedPostById(item.id);
      return cached ?? item;
    }
  }

  /// 发布新记录：示例模式直接追加内存；在线模式先写入本地待发队列并立即触发同步，
  /// 即使当前断网也能在首页立即展示并在恢复网络后自动补发。
  Future<void> submitPost({
    required PostType type,
    String? title,
    required String content,
    String? locationCity,
    required List<String> localImagePaths,
  }) async {
    final now = DateTime.now();
    final auth = _ref.read(authProvider);
    final cleanTitle =
        title != null && title.trim().isNotEmpty ? title.trim() : null;
    final cleanCity = locationCity != null && locationCity.trim().isNotEmpty
        ? locationCity.trim()
        : null;

    if (auth.demoMode) {
      final created = PostItem(
        id: 'demo-${_uuid.v4()}',
        type: type,
        title: cleanTitle,
        content: content.trim(),
        locationCity: cleanCity,
        recordTime: now,
        createdAt: now,
        updatedAt: now,
        images: localImagePaths.map((p) => 'file://$p').toList(),
      );
      state = state.copyWith(
        remotePosts: [created, ...state.remotePosts],
      );
      return;
    }

    final localPostId = 'local-${_uuid.v4()}';
    final pendingImages = <PendingImage>[];
    for (var i = 0; i < localImagePaths.length; i++) {
      final persisted =
          await MediaHelper.compressAndPersistForOutbox(localImagePaths[i]);
      pendingImages.add(
        PendingImage(
          localId: _uuid.v4(),
          pendingPostId: localPostId,
          localFilePath: persisted,
          sortOrder: i,
        ),
      );
    }

    final pendingPost = PendingPost(
      localId: localPostId,
      type: type,
      title: cleanTitle,
      content: content.trim(),
      locationCity: cleanCity,
      recordTime: now.toUtc(),
      status: SyncStatus.pending,
      createdAt: now.toUtc(),
      images: pendingImages,
    );

    await _db.insertPendingPost(pendingPost);
    final pending = await _db.getPendingPosts();
    state = state.copyWith(pendingPosts: pending);

    await syncPendingPosts();
  }

  Future<void> syncPendingPosts() async {
    if (_ref.read(authProvider).demoMode) return;
    final syncService = _ref.read(outboxSyncServiceProvider);
    final result = await syncService.syncAll();
    final pending = await _db.getPendingPosts();
    if (result.syncedPosts.isNotEmpty) {
      final existingIds = state.remotePosts.map((e) => e.id).toSet();
      final merged = [
        ...result.syncedPosts.where((e) => !existingIds.contains(e.id)),
        ...state.remotePosts,
      ];
      state = state.copyWith(
        remotePosts: merged,
        pendingPosts: pending,
      );
    } else {
      state = state.copyWith(pendingPosts: pending);
    }
  }

  Future<void> discardPendingPost(String localId) async {
    final target =
        state.pendingPosts.where((p) => p.localId == localId).firstOrNull;
    await _db.deletePendingPost(localId);
    if (target != null) {
      for (final img in target.images) {
        await MediaHelper.deleteLocalFileSilently(img.localFilePath);
      }
    }
    final pending = await _db.getPendingPosts();
    state = state.copyWith(pendingPosts: pending);
  }

  Future<void> deletePost(PostItem item) async {
    if (item.isPending) {
      await discardPendingPost(item.id);
      return;
    }
    if (_ref.read(authProvider).demoMode) {
      state = state.copyWith(
        remotePosts: state.remotePosts.where((p) => p.id != item.id).toList(),
      );
      return;
    }
    await _api.deletePost(item.id);
    await _db.deleteCachedPost(item.id);
    state = state.copyWith(
      remotePosts: state.remotePosts.where((p) => p.id != item.id).toList(),
    );
  }

  PostItem? findById(String id) {
    for (final p in state.visiblePosts) {
      if (p.id == id) return p;
    }
    return null;
  }
}
