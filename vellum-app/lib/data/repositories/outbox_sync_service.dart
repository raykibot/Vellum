import 'package:vellum_app/core/db/vellum_db.dart';
import 'package:vellum_app/core/media/media_helper.dart';
import 'package:vellum_app/core/network/api_client.dart';
import 'package:vellum_app/data/api/vellum_api.dart';
import 'package:vellum_app/data/models/models.dart';

class OutboxSyncResult {
  const OutboxSyncResult({
    this.syncedPosts = const [],
    this.authExpired = false,
  });

  final List<PostItem> syncedPosts;
  final bool authExpired;
}

/// 离线待补发队列服务（零额外同步接口）：
/// 恢复网络后直接按图片级断点续传调 /api/v1/files/upload，随后保留原 recordTime 调 POST /api/v1/posts。
class OutboxSyncService {
  OutboxSyncService({
    required VellumDb db,
    required VellumApi api,
  })  : _db = db,
        _api = api;

  final VellumDb _db;
  final VellumApi _api;

  bool _isSyncing = false;

  Future<OutboxSyncResult> syncAll() async {
    if (_isSyncing) return const OutboxSyncResult();
    _isSyncing = true;
    final synced = <PostItem>[];
    var authExpired = false;

    try {
      final queue = await _db.getPendingPosts();
      for (final item in queue) {
        await _db.updatePendingStatus(item.localId, SyncStatus.uploading);
        try {
          final uploadedIds = <String>[];
          for (final img in item.images) {
            if (img.uploadedImageId != null &&
                img.uploadedImageId!.isNotEmpty) {
              uploadedIds.add(img.uploadedImageId!);
              continue;
            }
            final uploaded = await _api.uploadImage(img.localFilePath);
            await _db.updatePendingImageUploadedId(img.localId, uploaded.id);
            uploadedIds.add(uploaded.id);
          }

          final created = await _api.createPost(
            type: item.type,
            title: item.title,
            content: item.content,
            locationCity: item.locationCity,
            recordTime: item.recordTime,
            imageIds: uploadedIds,
          );

          await _db.upsertCachedPosts([created]);
          await _db.deletePendingPost(item.localId);
          for (final img in item.images) {
            await MediaHelper.deleteLocalFileSilently(img.localFilePath);
          }
          synced.add(created);
        } on ApiException catch (e) {
          if (e.code == 401) {
            await _db.updatePendingStatus(
              item.localId,
              SyncStatus.pending,
              lastError: '登录已过期，重新登录后继续同步',
            );
            authExpired = true;
            break;
          }
          await _db.updatePendingStatus(
            item.localId,
            SyncStatus.failed,
            retryCount: item.retryCount + 1,
            lastError: e.message,
          );
        } catch (e) {
          await _db.updatePendingStatus(
            item.localId,
            SyncStatus.failed,
            retryCount: item.retryCount + 1,
            lastError: e.toString(),
          );
        }
      }
    } finally {
      _isSyncing = false;
    }

    return OutboxSyncResult(syncedPosts: synced, authExpired: authExpired);
  }
}
