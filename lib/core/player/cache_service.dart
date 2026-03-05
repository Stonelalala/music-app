import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/track.dart';

class CacheService extends ChangeNotifier {
  static const String cacheDirName = 'audio_cache';
  final Dio _dio = Dio();

  /// 获取缓存目录路径 (改为持久化目录)
  Future<Directory> get _cacheDir async {
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(baseDir.path, cacheDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 检查歌曲是否已缓存，返回文件对象，如果不存在则返回 null
  Future<File?> getCachedTrack(String trackId, String extension) async {
    final dir = await _cacheDir;
    final ext = extension.isEmpty ? '.mp3' : extension;
    final file = File(p.join(dir.path, '$trackId$ext'));
    if (await file.exists()) {
      // 更新访问时间
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return file;
    }
    return null;
  }

  /// 异步执行缓存任务
  Future<void> cacheTrack(Track track, String url, Map<String, String> headers,
      {int? maxCacheBytes}) async {
    try {
      final dir = await _cacheDir;
      final ext = track.extension.isEmpty ? '.mp3' : track.extension;
      final tempFile = File(p.join(dir.path, '${track.id}$ext.tmp'));
      final finalFile = File(p.join(dir.path, '${track.id}$ext'));
      final metaFile = File(p.join(dir.path, '${track.id}.json'));

      if (await finalFile.exists()) {
        // 如果文件存在但元数据缺失，补全它
        if (!await metaFile.exists()) {
          await metaFile.writeAsString(jsonEncode(track.toJson()));
        }
        return;
      }

      debugPrint('Downloading track to cache: ${track.title} -> ${finalFile.path}');

      // 下载文件并监听错误
      await _dio.download(
        url,
        tempFile.path,
        options: Options(headers: headers),
        onReceiveProgress: (count, total) {
          if (total > 0 && count == total) {
            debugPrint('Download finished for: ${track.title}');
          }
        },
      ).catchError((e) {
        debugPrint('Dio download error for ${track.title}: $e');
        throw e;
      });

      // 确保文件存在再重命名
      if (await tempFile.exists()) {
        await tempFile.rename(finalFile.path);
        // 保存元数据
        await metaFile.writeAsString(jsonEncode(track.toJson()));
        debugPrint('Successfully cached track: ${track.title}');
        notifyListeners(); // 通知 UI 刷新
      } else {
        debugPrint('Temp file does not exist after download: ${track.title}');
      }

      // 检查并清理缓存
      if (maxCacheBytes != null) {
        await _checkAndCleanup(maxCacheBytes);
      }
    } catch (e) {
      debugPrint('Cache error for ${track.title}: $e');
    }
  }

  /// 获取所有已缓存的歌曲元数据
  Future<List<Track>> getCachedTracks() async {
    try {
      final dir = await _cacheDir;
      final List<Track> cached = [];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            cached.add(Track.fromJson(jsonDecode(content)));
          } catch (e) {
            debugPrint('Failed to parse cache metadata: ${entity.path}');
          }
        }
      }
      return cached;
    } catch (_) {
      return [];
    }
  }

  /// 计算当前缓存占用空间
  Future<int> getTotalCacheSize() async {
    try {
      final dir = await _cacheDir;
      int total = 0;
      await for (final file in dir.list(recursive: false)) {
        if (file is File) {
          total += await file.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 清理所有缓存
  Future<void> clearAllCache() async {
    try {
      final dir = await _cacheDir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        notifyListeners(); // 通知清空
      }
    } catch (e) {
      debugPrint('Clear cache error: $e');
    }
  }

  /// LRU 清理逻辑：按修改时间降序排列，删除最旧的文件直到满足空间要求
  Future<void> _checkAndCleanup(int maxBytes) async {
    try {
      final dir = await _cacheDir;
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          files.add(entity);
        }
      }

      int currentSize = 0;
      for (var f in files) {
        currentSize += await f.length();
      }

      if (currentSize <= maxBytes) return;

      // 按修改时间从旧到新排序
      files.sort((a, b) =>
          a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      for (var file in files) {
        if (currentSize <= maxBytes * 0.8) break; // 清理到 80% 防止频繁清理
        final size = await file.length();
        await file.delete();
        currentSize -= size;
        debugPrint('LRU: Deleted old cache file ${file.path}');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }
}

final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

final cachedTracksProvider = FutureProvider<List<Track>>((ref) {
  final service = ref.watch(cacheServiceProvider);
  // 监听 ChangeNotifier 以在缓存变化时重新执行此 Future
  final notifier = _CacheUpdateNotifier(service);
  ref.watch(changeNotifierProvider(notifier));
  return service.getCachedTracks();
});

// 辅助 Provider 用于监听缓存变化
final changeNotifierProvider = ChangeNotifierProvider.family<ChangeNotifier, ChangeNotifier>((ref, notifier) => notifier);

class _CacheUpdateNotifier extends ChangeNotifier {
  _CacheUpdateNotifier(CacheService service) {
    service.addListener(notifyListeners);
  }
}
