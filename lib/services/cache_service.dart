import 'dart:io';

import 'package:ChatiX/services/file_converter_service.dart';

/// Глобальный кэш для файлов сообщений (из hex)
/// Решает главную проблему — повторную конвертацию hex → File при каждом rebuild'е списка
class MessageFileCache {
  static final MessageFileCache _instance = MessageFileCache._internal();
  factory MessageFileCache() => _instance;
  MessageFileCache._internal();

  // Кэш: ключ = messageId или hex (можно использовать messageId)
  final Map<String, File> _cache = {};

  /// Получить файл из кэша или конвертировать и сохранить
  Future<File?> getOrConvert(String messageId, Map<String, dynamic> msgData) async {
    // Сначала проверяем кэш
    if (_cache.containsKey(messageId)) {
      return _cache[messageId];
    }

    final hexData = msgData['hexData'];
    final fileName = msgData['fileName'];

    if (hexData == null || fileName == null) return null;

    try {
      final file = await FileConverterService.hexToFile(hexData, fileName);
      _cache[messageId] = file; // сохраняем в кэш
      return file;
    } catch (e) {
      print('Ошибка конвертации файла из hex: $e');
      return null;
    }
  }

  /// Очистить кэш конкретного сообщения
  void remove(String messageId) {
    _cache.remove(messageId);
  }

  /// Полная очистка кэша (например, при выходе из чата)
  void clear() {
    _cache.clear();
  }

  /// Получить размер кэша в памяти (примерно)
  int get size => _cache.length;
}