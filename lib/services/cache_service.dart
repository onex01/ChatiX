import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  static Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return 0;
      
      int size = 0;
      await for (var entity in tempDir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/cache');
      if (await cacheDir.exists()) {
        await for (var entity in cacheDir.list(recursive: true)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
      
      return size ~/ (1024 * 1024); // Возвращаем в МБ
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }
}