import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:vellum_app/data/models/models.dart';

/// 本地 SQLite（3 张零外键极简表）：
/// - cached_posts：缓存时间流列表与按需拉取的长文全文
/// - pending_posts：断网待补发记录
/// - pending_images：待上传图片与断点续传 ID
class VellumDb {
  VellumDb._(this._db);

  final Database _db;

  static Future<VellumDb> open() async {
    final dir = await getDatabasesPath();
    final dbPath = p.join(dir, 'vellum.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_posts (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT,
            content TEXT NOT NULL,
            full_content TEXT,
            content_truncated INTEGER NOT NULL DEFAULT 0,
            location_city TEXT,
            record_time INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            images_json TEXT NOT NULL DEFAULT '[]',
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_cached_posts_time ON cached_posts(record_time DESC)',
        );

        await db.execute('''
          CREATE TABLE pending_posts (
            local_id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT,
            content TEXT NOT NULL,
            location_city TEXT,
            record_time INTEGER NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_images (
            local_id TEXT PRIMARY KEY,
            pending_post_id TEXT NOT NULL,
            local_file_path TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            uploaded_image_id TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_pending_images_post ON pending_images(pending_post_id, sort_order ASC)',
        );
      },
    );
    return VellumDb._(db);
  }

  Future<void> upsertCachedPosts(List<PostItem> items) async {
    if (items.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final item in items) {
      final existing = await _db.query(
        'cached_posts',
        columns: ['full_content'],
        where: 'id = ?',
        whereArgs: [item.id],
        limit: 1,
      );
      final oldFull = existing.isNotEmpty
          ? existing.first['full_content'] as String?
          : null;
      final fullContent = !item.contentTruncated ? item.content : oldFull;

      batch.insert(
        'cached_posts',
        {
          'id': item.id,
          'type': item.type.apiValue,
          'title': item.title,
          'content': item.content,
          'full_content': fullContent,
          'content_truncated': item.contentTruncated ? 1 : 0,
          'location_city': item.locationCity,
          'record_time': item.recordTime.millisecondsSinceEpoch,
          'created_at': item.createdAt.millisecondsSinceEpoch,
          'updated_at': item.updatedAt.millisecondsSinceEpoch,
          'images_json': jsonEncode(item.images),
          'cached_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateCachedFullContent(PostItem detail) async {
    await upsertCachedPosts([detail.copyWith(contentTruncated: false)]);
  }

  Future<List<PostItem>> queryCachedPosts({
    PostFilterType filter = PostFilterType.all,
  }) async {
    final where = filter == PostFilterType.all ? null : 'type = ?';
    final whereArgs =
        filter == PostFilterType.all ? null : [filter.apiValue];
    final rows = await _db.query(
      'cached_posts',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'record_time DESC, id DESC',
    );
    return rows.map(_mapCachedRow).toList();
  }

  Future<PostItem?> getCachedPostById(String id) async {
    final rows = await _db.query(
      'cached_posts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapCachedRow(rows.first);
  }

  Future<void> deleteCachedPost(String id) async {
    await _db.delete('cached_posts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCachedPosts() async {
    await _db.delete('cached_posts');
  }

  Future<void> insertPendingPost(PendingPost post) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'pending_posts',
        {
          'local_id': post.localId,
          'type': post.type.apiValue,
          'title': post.title,
          'content': post.content,
          'location_city': post.locationCity,
          'record_time': post.recordTime.millisecondsSinceEpoch,
          'status': post.status.name,
          'retry_count': post.retryCount,
          'last_error': post.lastError,
          'created_at': post.createdAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final img in post.images) {
        await txn.insert(
          'pending_images',
          {
            'local_id': img.localId,
            'pending_post_id': post.localId,
            'local_file_path': img.localFilePath,
            'sort_order': img.sortOrder,
            'uploaded_image_id': img.uploadedImageId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<PendingPost>> getPendingPosts() async {
    final postRows = await _db.query(
      'pending_posts',
      orderBy: 'record_time DESC',
    );
    if (postRows.isEmpty) return const [];

    final imageRows = await _db.query(
      'pending_images',
      orderBy: 'sort_order ASC',
    );
    final imagesByPost = <String, List<PendingImage>>{};
    for (final row in imageRows) {
      final postId = row['pending_post_id'] as String;
      imagesByPost.putIfAbsent(postId, () => []).add(
            PendingImage(
              localId: row['local_id'] as String,
              pendingPostId: postId,
              localFilePath: row['local_file_path'] as String,
              sortOrder: (row['sort_order'] as num).toInt(),
              uploadedImageId: row['uploaded_image_id'] as String?,
            ),
          );
    }

    return postRows.map((row) {
      final localId = row['local_id'] as String;
      final statusRaw = row['status'] as String? ?? 'pending';
      final status = SyncStatus.values.firstWhere(
        (s) => s.name == statusRaw,
        orElse: () => SyncStatus.pending,
      );
      return PendingPost(
        localId: localId,
        type: PostType.fromApi(row['type'] as String? ?? 'MOMENT'),
        title: row['title'] as String?,
        content: row['content'] as String? ?? '',
        locationCity: row['location_city'] as String?,
        recordTime: DateTime.fromMillisecondsSinceEpoch(
          (row['record_time'] as num).toInt(),
        ),
        status: status,
        retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
        lastError: row['last_error'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at'] as num).toInt(),
        ),
        images: imagesByPost[localId] ?? const [],
      );
    }).toList();
  }

  Future<void> updatePendingStatus(
    String localId,
    SyncStatus status, {
    int? retryCount,
    String? lastError,
  }) async {
    final values = <String, Object?>{
      'status': status.name,
      'last_error': lastError,
    };
    if (retryCount != null) {
      values['retry_count'] = retryCount;
    }
    await _db.update(
      'pending_posts',
      values,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> updatePendingImageUploadedId(
    String imageLocalId,
    String uploadedId,
  ) async {
    await _db.update(
      'pending_images',
      {'uploaded_image_id': uploadedId},
      where: 'local_id = ?',
      whereArgs: [imageLocalId],
    );
  }

  Future<void> deletePendingPost(String localId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'pending_images',
        where: 'pending_post_id = ?',
        whereArgs: [localId],
      );
      await txn.delete(
        'pending_posts',
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });
  }

  PostItem _mapCachedRow(Map<String, Object?> row) {
    final fullContent = row['full_content'] as String?;
    final summaryOrBody = row['content'] as String? ?? '';
    final effectiveContent =
        (fullContent != null && fullContent.isNotEmpty)
            ? fullContent
            : summaryOrBody;
    final truncated =
        (fullContent == null || fullContent.isEmpty) &&
        ((row['content_truncated'] as num?)?.toInt() ?? 0) == 1;

    List<String> images = const [];
    try {
      final raw = jsonDecode(row['images_json'] as String? ?? '[]');
      if (raw is List) {
        images = raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return PostItem(
      id: row['id'] as String,
      type: PostType.fromApi(row['type'] as String? ?? 'MOMENT'),
      title: row['title'] as String?,
      content: effectiveContent,
      locationCity: row['location_city'] as String?,
      recordTime: DateTime.fromMillisecondsSinceEpoch(
        (row['record_time'] as num).toInt(),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at'] as num).toInt(),
      ),
      images: images,
      contentTruncated: truncated,
    );
  }
}
