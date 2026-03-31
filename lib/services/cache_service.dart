import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CacheService {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();
  
  static Future<void> clearCache() async {
    await _cacheManager.emptyCache();
    
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
  
  static Future<int> getCacheSize() async {
    final tempDir = await getTemporaryDirectory();
    if (!await tempDir.exists()) return 0;
    
    int size = 0;
    await for (var file in tempDir.list(recursive: true)) {
      if (file is File) {
        size += await file.length();
      }
    }
    return size ~/ (1024 * 1024); // Возвращаем в МБ
  }
}