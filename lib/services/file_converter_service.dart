import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

class FileConverterService {
  // Максимальный размер файла для hex конвертации (500 КБ)
  // Firestore имеет лимит на размер документа 1 МБ
  static const int maxFileSize = 500 * 1024; // 500 KB
  
  /// Конвертирует файл в hex строку
  static Future<String> fileToHex(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return _bytesToHex(bytes);
    } catch (e) {
      print('Ошибка конвертации файла в hex: $e');
      rethrow;
    }
  }
  
  /// Конвертирует hex строку обратно в файл
  static Future<File> hexToFile(String hexData, String fileName) async {
    try {
      final bytes = _hexToBytes(hexData);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('Ошибка конвертации hex в файл: $e');
      rethrow;
    }
  }
  
  /// Конвертирует байты в hex строку
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Конвертирует hex строку в байты
  static List<int> _hexToBytes(String hex) {
    final List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      final byte = int.parse(hex.substring(i, i + 2), radix: 16);
      bytes.add(byte);
    }
    return bytes;
  }
  
  /// Проверяет, можно ли конвертировать файл
  static Future<bool> canConvert(File file) async {
    final size = await file.length();
    return size <= maxFileSize;
  }
  
  /// Получает размер файла в удобном формате
  static Future<String> getFileSizeString(File file) async {
    final size = await file.length();
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}