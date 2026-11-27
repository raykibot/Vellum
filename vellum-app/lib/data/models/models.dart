enum PostType {
  moment('MOMENT'),
  article('ARTICLE');

  const PostType(this.apiValue);
  final String apiValue;

  static PostType fromApi(String raw) {
    return raw.toUpperCase() == 'ARTICLE' ? PostType.article : PostType.moment;
  }
}

enum PostFilterType {
  all('ALL', '全部'),
  moment('MOMENT', '动态'),
  article('ARTICLE', '长文');

  const PostFilterType(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum SyncStatus { pending, uploading, failed }

class PostItem {
  const PostItem({
    required this.id,
    required this.type,
    this.title,
    required this.content,
    this.locationCity,
    required this.recordTime,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.contentTruncated = false,
    this.pendingStatus,
    this.pendingError,
  });

  final String id;
  final PostType type;
  final String? title;
  final String content;
  final String? locationCity;
  final DateTime recordTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> images;
  final bool contentTruncated;
  final SyncStatus? pendingStatus;
  final String? pendingError;

  bool get isPending => pendingStatus != null;

  PostItem copyWith({
    String? id,
    PostType? type,
    String? title,
    String? content,
    String? locationCity,
    DateTime? recordTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
    bool? contentTruncated,
    SyncStatus? pendingStatus,
    String? pendingError,
  }) {
    return PostItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      locationCity: locationCity ?? this.locationCity,
      recordTime: recordTime ?? this.recordTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      contentTruncated: contentTruncated ?? this.contentTruncated,
      pendingStatus: pendingStatus ?? this.pendingStatus,
      pendingError: pendingError ?? this.pendingError,
    );
  }

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : const <String>[];
    return PostItem(
      id: json['id'] as String,
      type: PostType.fromApi(json['type'] as String? ?? 'MOMENT'),
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      locationCity: json['locationCity'] as String?,
      recordTime: DateTime.parse(json['recordTime'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      images: images,
      contentTruncated: json['contentTruncated'] as bool? ?? false,
    );
  }
}

class CursorPageResult<T> {
  const CursorPageResult({
    required this.size,
    required this.hasMore,
    this.nextCursorTime,
    this.nextCursorId,
    required this.items,
  });

  final int size;
  final bool hasMore;
  final String? nextCursorTime;
  final String? nextCursorId;
  final List<T> items;

  factory CursorPageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemDecoder,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return CursorPageResult(
      size: (json['size'] as num?)?.toInt() ?? 12,
      hasMore: json['hasMore'] as bool? ?? false,
      nextCursorTime: json['nextCursorTime'] as String?,
      nextCursorId: json['nextCursorId'] as String?,
      items: rawItems
          .map((e) => itemDecoder(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LoginResponse {
  const LoginResponse({required this.token, required this.expiresAt});

  final String token;
  final String expiresAt;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      expiresAt: json['expiresAt'] as String,
    );
  }
}

class UploadFileResponse {
  const UploadFileResponse({required this.id, required this.url});

  final String id;
  final String url;

  factory UploadFileResponse.fromJson(Map<String, dynamic> json) {
    return UploadFileResponse(
      id: json['id'] as String,
      url: json['url'] as String,
    );
  }
}

class PendingImage {
  const PendingImage({
    required this.localId,
    required this.pendingPostId,
    required this.localFilePath,
    required this.sortOrder,
    this.uploadedImageId,
  });

  final String localId;
  final String pendingPostId;
  final String localFilePath;
  final int sortOrder;
  final String? uploadedImageId;
}

class PendingPost {
  const PendingPost({
    required this.localId,
    required this.type,
    this.title,
    required this.content,
    this.locationCity,
    required this.recordTime,
    required this.status,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    this.images = const [],
  });

  final String localId;
  final PostType type;
  final String? title;
  final String content;
  final String? locationCity;
  final DateTime recordTime;
  final SyncStatus status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final List<PendingImage> images;

  PostItem toTimelinePostItem() {
    return PostItem(
      id: localId,
      type: type,
      title: title,
      content: content,
      locationCity: locationCity,
      recordTime: recordTime,
      createdAt: createdAt,
      updatedAt: createdAt,
      images: images.map((e) => 'file://${e.localFilePath}').toList(),
      contentTruncated: false,
      pendingStatus: status,
      pendingError: lastError,
    );
  }
}

/// 离线示例预览数据，与 Figma 设计稿 4:2 / 8:2 文案与配图保持完全一致，
/// 方便未连接后端时直接预览与交互全部 7 个页面。
class DemoSeedData {
  static List<PostItem> initialPosts() {
    return [
      PostItem(
        id: 'demo-20261124',
        type: PostType.moment,
        title: null,
        content: '下班后绕去海边。风很轻，\n天色慢慢变成了蓝灰色。',
        locationCity: '深圳市',
        recordTime: DateTime(2026, 11, 24, 16, 1),
        createdAt: DateTime(2026, 11, 24, 16, 1),
        updatedAt: DateTime(2026, 11, 24, 16, 1),
        images: const [
          'asset://assets/demo/shoreline.png',
          'asset://assets/demo/grasses.png',
        ],
      ),
      PostItem(
        id: 'demo-20261123',
        type: PostType.article,
        title: '把日子过得慢一点',
        content: '''合上电脑，才发现窗外已经暗了。
试着不把每一段空白都填满。

> 慢下来，不是停在原地，
> 而是重新看见正在发生的生活。

## 留给自己的小事

- 散步时，把手机放进口袋
- 读几页书，不急着读完
- 记下一个值得留下的瞬间''',
        locationCity: '深圳市',
        recordTime: DateTime(2026, 11, 23, 21, 30),
        createdAt: DateTime(2026, 11, 23, 21, 30),
        updatedAt: DateTime(2026, 11, 23, 21, 30),
        images: const ['asset://assets/demo/shoreline.png'],
      ),
      PostItem(
        id: 'demo-20261122',
        type: PostType.moment,
        title: null,
        content: '周末原本想读完半本书，最后只翻了几页。阳光落在纸上，也很好。',
        locationCity: '杭州市',
        recordTime: DateTime(2026, 11, 22, 14, 20),
        createdAt: DateTime(2026, 11, 22, 14, 20),
        updatedAt: DateTime(2026, 11, 22, 14, 20),
        images: const [],
      ),
    ];
  }
}
