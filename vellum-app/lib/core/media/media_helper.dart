import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:vellum_app/core/motion/vellum_motion.dart';
import 'package:vellum_app/core/storage/app_storage.dart';
import 'package:vellum_app/core/theme/vellum_theme.dart';

class MediaHelper {
  static const _uuid = Uuid();

  /// 将选中的照片压缩至长边不超过 1920px（质量 82%）并持久化到应用私有目录，
  /// 确保离线待补发期间不会被系统清理临时缓存。
  static Future<String> compressAndPersistForOutbox(String sourcePath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final outboxDir = Directory(p.join(docDir.path, 'outbox_images'));
    await outboxDir.create(recursive: true);

    final ext = p.extension(sourcePath).toLowerCase();
    final isWebp = ext == '.webp';
    final targetPath = p.join(
      outboxDir.path,
      '${_uuid.v4()}${isWebp ? '.webp' : '.jpg'}',
    );

    if (isWebp) {
      await File(sourcePath).copy(targetPath);
      return targetPath;
    }

    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      minWidth: 1920,
      minHeight: 1920,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    if (result != null && await File(result.path).exists()) {
      return result.path;
    }

    final fallback = p.join(outboxDir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(fallback);
    return fallback;
  }

  static Future<void> deleteLocalFileSilently(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// 用图片接口 ID 作为稳定 cacheKey，避免切换服务域名后重复拉取。
  static String extractCacheKey(String rawUrl) {
    final match = RegExp(r'/api/v1/files/([^/?#]+)').firstMatch(rawUrl);
    if (match != null) return 'vellum_img_${match.group(1)}';
    return rawUrl;
  }
}

/// 统一图片展示组件：同时支持本地示例资产（asset://）、离线本地文件（file://）
/// 以及通过 Header 携带 Bearer Token 鉴权的远端 MinIO 图片。
class VellumImage extends StatelessWidget {
  const VellumImage({
    super.key,
    required this.source,
    this.baseUrl = '',
    this.token,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String source;
  final String baseUrl;
  final String? token;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.vellum;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width != null ? (width! * dpr).round() : null;
    final cacheH = (width == null && height != null)
        ? (height! * dpr).round()
        : null;

    if (source.startsWith('asset://')) {
      return Image.asset(
        source.substring('asset://'.length),
        width: width,
        height: height,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        gaplessPlayback: true,
        fit: fit,
      );
    }

    if (source.startsWith('file://') ||
        source.startsWith('/data/') ||
        source.startsWith('/storage/')) {
      final filePath =
          source.startsWith('file://') ? source.substring('file://'.length) : source;
      return Image.file(
        File(filePath),
        width: width,
        height: height,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        gaplessPlayback: true,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(c),
      );
    }

    final resolved = AppStorage.resolveMediaUrl(source, baseUrl);
    if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
      return _placeholder(c);
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      cacheKey: MediaHelper.extractCacheKey(source),
      httpHeaders: token != null && token!.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null,
      width: width,
      height: height,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeInCurve: VellumMotion.easeOut,
      fit: fit,
      placeholder: (_, __) => Container(color: c.surface),
      errorWidget: (_, __, ___) => _placeholder(c),
    );
  }

  Widget _placeholder(VellumColors c) {
    return Container(
      width: width,
      height: height,
      color: c.surface,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, size: 20, color: c.muted),
    );
  }
}
