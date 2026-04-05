import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../version.dart';
import 'logger.dart';

class UpdateService {
  static const String baseUrl = 'https://rizz.onex01.ru/';

  static Future<Map<String, dynamic>?> checkForUpdates() async {
    await AppLogger.info('Проверка обновлений: начало');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/version.json'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final currentVersion = AppVersion.version;

        await AppLogger.info('Текущая версия: $currentVersion, последняя: $latestVersion');

        if (_isNewerVersion(latestVersion, currentVersion)) {
          await AppLogger.info('Доступно обновление до версии $latestVersion');
          return data;
        } else {
          await AppLogger.info('Обновление не требуется');
          return null;
        }
      } else {
        await AppLogger.error('Ошибка проверки обновлений: статус ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      await AppLogger.error('Исключение при проверке обновлений', e, stack);
      return null;
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      AppLogger.error('Ошибка сравнения версий', e);
      return false;
    }
  }

  static Future<void> showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo) async {
    await AppLogger.info('Показ диалога обновления, версия ${updateInfo['version']}');

    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Новое обновление', // короткий заголовок, не вылезает
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Версия ${updateInfo['version']}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Доступна новая версия приложения!', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Размер: ${(updateInfo['fileSize'] / 1024 / 1024).toStringAsFixed(1)} МБ',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Рекомендуем обновиться для получения новых функций и исправлений',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Позже', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Обновить сейчас'),
            ),
          ],
        );
      },
    );

    if (shouldUpdate == true && updateInfo['downloadUrl'] != null) {
      await AppLogger.info('Пользователь согласился на обновление, начинаем загрузку');
      await _showDownloadProgress(context, updateInfo['downloadUrl']);
    } else {
      await AppLogger.info('Пользователь отклонил обновление');
    }
  }

  static Future<void> _showDownloadProgress(BuildContext context, String downloadUrl) async {
    // Диалог загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Загрузка обновления...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('Пожалуйста, подождите', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        );
      },
    );

    try {
      final String targetPath = await _getApkSavePath();
      await AppLogger.info('Сохранение APK в: $targetPath');
      final File file = File(targetPath);

      final response = await http.get(Uri.parse(downloadUrl));
      await AppLogger.info('Загрузка завершена, размер: ${response.bodyBytes.length} байт');
      await file.writeAsBytes(response.bodyBytes);
      await AppLogger.info('Файл успешно записан');

      // Закрываем диалог прогресса
      if (context.mounted) Navigator.of(context).pop();

      // Показываем сообщение об успехе
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обновление загружено. Открываем установщик...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Проверяем разрешение на установку (только Android)
      if (Platform.isAndroid && !await _hasInstallPermission()) {
        await _showInstallPermissionDialog(context, targetPath);
      } else {
        await _openApkAndInstall(context, targetPath);
      }
    } catch (e, stack) {
      await AppLogger.error('Ошибка при загрузке/установке обновления', e, stack);
      if (context.mounted) {
        Navigator.of(context).pop(); // закрываем диалог прогресса, если ещё открыт
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки обновления: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Проверяет, есть ли разрешение на установку из неизвестных источников (Android 8+)
  static Future<bool> _hasInstallPermission() async {
    if (!Platform.isAndroid) return true;
    // Используем каналы для вызова системного метода
    const platform = MethodChannel('com.dualproj.rizz/install_permission');
    try {
      final bool result = await platform.invokeMethod('hasInstallPermission');
      return result;
    } catch (e) {
      await AppLogger.error('Ошибка проверки разрешения на установку', e);
      return false; // если не удалось проверить, считаем что нет разрешения
    }
  }

  /// Показывает диалог с инструкцией по включению установки из неизвестных источников
  static Future<void> _showInstallPermissionDialog(BuildContext context, String apkPath) async {
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Требуется разрешение'),
        content: const Text(
          'Для установки обновления необходимо разрешить установку из неизвестных источников для этого приложения.\n\n'
          'Перейти в настройки и включить разрешение?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Не сейчас'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );

    if (shouldOpenSettings == true) {
      // Открываем настройки приложения
      const platform = MethodChannel('com.dualproj.rizz/install_permission');
      await platform.invokeMethod('openAppSettings');
      // После возврата из настроек пробуем открыть APK снова
      if (context.mounted) {
        await _openApkAndInstall(context, apkPath);
      }
    } else {
      // Показываем путь к файлу, чтобы пользователь установил вручную
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл сохранён: $apkPath\nУстановите его вручную после включения разрешения.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  /// Открывает APK для установки
  static Future<void> _openApkAndInstall(BuildContext context, String apkPath) async {
    await AppLogger.info('Попытка открыть APK: $apkPath');
    final result = await OpenFile.open(apkPath, type: 'application/vnd.android.package-archive');
    if (result.type == ResultType.done) {
      await AppLogger.info('APK открыт успешно, установщик запущен');
    } else {
      await AppLogger.error('Не удалось открыть APK, результат: ${result.type}, сообщение: ${result.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть установщик. Файл сохранён: $apkPath'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Возвращает путь для сохранения APK в публичной папке Download/Rizz/Update
  static Future<String> _getApkSavePath() async {
    try {
      if (Platform.isAndroid) {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) {
          throw Exception('Не удалось получить доступ к папке Downloads');
        }
        final updateDir = Directory('${downloadsDir.path}/Rizz/Update');
        if (!await updateDir.exists()) {
          await updateDir.create(recursive: true);
          await AppLogger.info('Создана директория: ${updateDir.path}');
        }
        final path = '${updateDir.path}/Rizz_update.apk';
        await AppLogger.debug('Сформирован путь: $path');
        return path;
      } else {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/Rizz_update.apk';
        await AppLogger.debug('Используется временная директория: $path');
        return path;
      }
    } catch (e, stack) {
      AppLogger.error('Ошибка получения пути для сохранения APK', e, stack);
      rethrow;
    }
  }
}