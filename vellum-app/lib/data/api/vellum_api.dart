import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:vellum_app/core/network/api_client.dart';
import 'package:vellum_app/data/models/models.dart';

class VellumApi {
  VellumApi(this._client);

  final ApiClient _client;

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) {
    return _client.post<LoginResponse>(
      '/api/v1/auth/login',
      data: {'username': username, 'password': password},
      decoder: (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CursorPageResult<PostItem>> fetchPosts({
    int size = 15,
    PostFilterType type = PostFilterType.all,
    String? cursorTime,
    String? cursorId,
  }) {
    final query = <String, dynamic>{
      'size': size,
      if (type != PostFilterType.all) 'type': type.apiValue,
      if (cursorTime != null && cursorId != null) ...{
        'cursorTime': cursorTime,
        'cursorId': cursorId,
      },
    };
    return _client.get<CursorPageResult<PostItem>>(
      '/api/v1/posts',
      queryParameters: query,
      decoder: (json) => CursorPageResult.fromJson(
        json as Map<String, dynamic>,
        PostItem.fromJson,
      ),
    );
  }

  Future<PostItem> fetchPostDetail(String id) {
    return _client.get<PostItem>(
      '/api/v1/posts/${Uri.encodeComponent(id)}',
      decoder: (json) => PostItem.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PostItem> createPost({
    required PostType type,
    String? title,
    required String content,
    String? locationCity,
    required DateTime recordTime,
    List<String>? imageIds,
  }) {
    return _client.post<PostItem>(
      '/api/v1/posts',
      data: {
        'type': type.apiValue,
        'title': title,
        'content': content,
        'locationCity': locationCity,
        'recordTime': recordTime.toUtc().toIso8601String(),
        if (imageIds != null && imageIds.isNotEmpty) 'imageIds': imageIds,
      },
      decoder: (json) => PostItem.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> deletePost(String id) {
    return _client.delete('/api/v1/posts/${Uri.encodeComponent(id)}');
  }

  Future<UploadFileResponse> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: p.basename(filePath),
      ),
    });
    return _client.post<UploadFileResponse>(
      '/api/v1/files/upload',
      data: formData,
      receiveTimeout: const Duration(seconds: 60),
      decoder: (json) =>
          UploadFileResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<({File file, String? filename})> downloadExportZip({
    required String savePath,
    String? startDate,
    String? endDate,
    PostFilterType type = PostFilterType.all,
    void Function(int received, int total)? onProgress,
  }) {
    return _client.downloadToFile(
      '/api/v1/exports/zip',
      savePath: savePath,
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (type != PostFilterType.all) 'type': type.apiValue,
      },
      onProgress: onProgress,
    );
  }

  Future<({File file, String? filename})> downloadExportMarkdown({
    required String savePath,
    String? startDate,
    String? endDate,
    PostFilterType type = PostFilterType.all,
    void Function(int received, int total)? onProgress,
  }) {
    return _client.downloadToFile(
      '/api/v1/exports/markdown',
      savePath: savePath,
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (type != PostFilterType.all) 'type': type.apiValue,
      },
      onProgress: onProgress,
    );
  }
}
