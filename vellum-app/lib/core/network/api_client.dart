import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vellum_app/core/storage/app_storage.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => message;
}

/// 统一网络客户端：自动注入动态 baseUrl、JWT Bearer Token，并拆包 `Result<T>`。
class ApiClient {
  ApiClient({
    required AppStorage storage,
    required VoidCallback onUnauthorized,
  })  : _storage = storage,
        _onUnauthorized = onUnauthorized {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final baseUrl = _storage.getApiBaseUrl();
          if (baseUrl.isEmpty) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: ApiException(400, '请先配置服务器地址'),
                type: DioExceptionType.unknown,
              ),
            );
            return;
          }
          options.baseUrl = baseUrl;
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final AppStorage _storage;
  final VoidCallback _onUnauthorized;
  late final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? decoder,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _unwrap<T>(response.data, decoder);
    } catch (e) {
      throw _translateError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Duration? receiveTimeout,
    T Function(dynamic json)? decoder,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        options: receiveTimeout != null
            ? Options(receiveTimeout: receiveTimeout)
            : null,
      );
      return _unwrap<T>(response.data, decoder);
    } catch (e) {
      throw _translateError(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      final response = await _dio.delete<dynamic>(path);
      _unwrap<dynamic>(response.data, null);
    } catch (e) {
      throw _translateError(e);
    }
  }

  /// 下载文件流（支持进度回调，并自动解析服务端在失败时返回的 JSON 错误体）。
  Future<({File file, String? filename})> downloadToFile(
    String path, {
    required String savePath,
    Map<String, dynamic>? queryParameters,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final bytes = response.data ?? const <int>[];
      final contentType =
          response.headers.value('content-type')?.toLowerCase() ?? '';
      if ((response.statusCode ?? 500) >= 400 ||
          contentType.contains('application/json')) {
        final decoded = _tryParseJsonBytes(bytes);
        if (decoded != null) {
          final code = (decoded['code'] as num?)?.toInt() ??
              response.statusCode ??
              500;
          final msg = decoded['message']?.toString() ?? '导出失败';
          if (code == 401 || response.statusCode == 401) {
            _onUnauthorized();
          }
          throw ApiException(code, msg);
        }
        throw ApiException(response.statusCode ?? 500, '导出失败');
      }

      final file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);

      final disposition = response.headers.value('content-disposition');
      final filename = _extractFilename(disposition);
      return (file: file, filename: filename);
    } catch (e) {
      throw _translateError(e);
    }
  }

  T _unwrap<T>(dynamic payload, T Function(dynamic json)? decoder) {
    if (payload is Map<String, dynamic> && payload['code'] is num) {
      final code = (payload['code'] as num).toInt();
      if (code == 0) {
        final data = payload['data'];
        if (decoder != null) return decoder(data);
        return data as T;
      }
      if (code == 401) {
        _onUnauthorized();
      }
      throw ApiException(code, payload['message']?.toString() ?? '请求失败');
    }
    throw ApiException(500, '响应格式异常');
  }

  ApiException _translateError(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      if (error.error is ApiException) {
        return error.error as ApiException;
      }
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        final code = (data['code'] as num?)?.toInt() ?? status ?? 500;
        if (status == 401 || code == 401) {
          _onUnauthorized();
        }
        return ApiException(code, data['message'].toString());
      }
      if (data is List<int>) {
        final parsed = _tryParseJsonBytes(data);
        if (parsed != null) {
          final code = (parsed['code'] as num?)?.toInt() ?? status ?? 500;
          if (status == 401 || code == 401) {
            _onUnauthorized();
          }
          return ApiException(
              code, parsed['message']?.toString() ?? '请求失败');
        }
      }
      if (status == 401) {
        _onUnauthorized();
        return ApiException(401, '登录已过期，请重新登录');
      }
      if (status != null) {
        return ApiException(status, '请求失败 ($status)');
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return ApiException(0, '连接超时，请检查网络');
      }
      return ApiException(0, '无法连接服务器');
    }
    return ApiException(500, error.toString());
  }

  Map<String, dynamic>? _tryParseJsonBytes(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return null;
  }

  String? _extractFilename(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;
    final utf8Match =
        RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
            .firstMatch(disposition);
    if (utf8Match != null) {
      try {
        return Uri.decodeComponent(
          utf8Match.group(1)!.trim().replaceAll(RegExp(r'''^["']|["']$'''), ''),
        );
      } catch (_) {}
    }
    final plainMatch =
        RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
            .firstMatch(disposition);
    return plainMatch?.group(1)?.trim();
  }
}
