import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageManager {
  // Limite recomendado de alerta (exemplo: 50 Megabytes de histórico/cache)
  static const int maxCacheBytes = 50 * 1024 * 1024;

  static Future<bool> needsCleanup() async {
    final dir = await getApplicationDocumentsDirectory();
    int totalSize = 0;
    
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    
    return totalSize > maxCacheBytes;
  }

  static Future<void> clearOldCache() async {
    final dir = await getApplicationDocumentsDirectory();
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}
