import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static const String _logFileName = 'rizz_log.txt';
  static File? _logFile;
  static bool _initialized = false;

  /// Инициализация: создание файла лога
  static Future<void> init() async {
    if (_initialized) return;
    
    Directory dir;
    try {
      // Для Android/iOS используем документы
      dir = await getApplicationDocumentsDirectory();
    } catch (e) {
      // fallback
      dir = await getTemporaryDirectory();
    }
    
    _logFile = File('${dir.path}/$_logFileName');
    // Создаём файл, если не существует
    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }
    
    _initialized = true;
    _write('=== Rizz Log Started === ${DateTime.now()} ===\n');
    _write('Device info: TODO\n\n');
  }

  static Future<void> _write(String text) async {
    if (!_initialized) return;
    try {
      await _logFile!.writeAsString(text, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  /// Информационное сообщение
  static Future<void> info(String message) async {
    final log = '[INFO] ${DateTime.now()} - $message\n';
    debugPrint(log);
    await _write(log);
  }

  /// Ошибка
  static Future<void> error(String message, [dynamic error, StackTrace? stack]) async {
    final log = '[ERROR] ${DateTime.now()} - $message\n';
    debugPrint(log);
    await _write(log);
    if (error != null) {
      final errLog = '  Exception: $error\n';
      debugPrint(errLog);
      await _write(errLog);
    }
    if (stack != null) {
      final stackLog = '  StackTrace: $stack\n';
      debugPrint(stackLog);
      await _write(stackLog);
    }
  }

  /// Отладочное сообщение (только в debug режиме)
  static Future<void> debug(String message) async {
    if (kDebugMode) {
      final log = '[DEBUG] ${DateTime.now()} - $message\n';
      debugPrint(log);
      await _write(log);
    }
  }

  /// Сохранить исключение Flutter
  static void handleFlutterError(FlutterErrorDetails details) {
    final message = '${details.exception}\n${details.stack ?? ''}';
    error('Flutter error: $message', details.exception, details.stack);
  }
}