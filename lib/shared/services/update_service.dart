import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get_it/get_it.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/logger/app_logger.dart';
import '../../core/platform/platform_info.dart';
import '../../version.dart';

class UpdateInfo {
  final String version;
  final String androidUrl;
  final String? windowsUrl;
  final String? linuxUrl;
  final String? macUrl;
  final int fileSize;

  UpdateInfo({
    required this.version,
    required this.androidUrl,
    required this.fileSize,
    this.windowsUrl,
    this.linuxUrl,
    this.macUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'],
      androidUrl: json['androidUrl'] ?? json['downloadUrl'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      windowsUrl: json['windowsUrl'],
      linuxUrl: json['linuxUrl'],
      macUrl: json['macUrl'],
    );
  }

  String? get urlForCurrentPlatform {
    GetIt.I<PlatformInfo>();
    if (Platform.isAndroid) return androidUrl;
    if (Platform.isWindows) return windowsUrl;
    if (Platform.isLinux) return linuxUrl;
    if (Platform.isMacOS) return macUrl;
    return null;
  }
}

class UpdateService {
  static const String baseUrl = 'https://rizz.onex01.ru/';
  final _logger = GetIt.I<AppLogger>();
  final _platform = GetIt.I<PlatformInfo>();

  Future<UpdateInfo?> checkForUpdates() async {
    await _logger.info('Checking for updates...');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/version.json'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final currentVersion = AppVersion.version;

        if (_isNewerVersion(latestVersion, currentVersion)) {
          await _logger.info('Update available: $latestVersion');
          return UpdateInfo.fromJson(data);
        }
      }
      return null;
    } catch (e, stack) {
      await _logger.error('Update check failed', error: e, stack: stack);
      return null;
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Доступна новая версия ${info.version}'),
        content: Text('Размер: ${(info.fileSize / 1024 / 1024).toStringAsFixed(1)} МБ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Позже')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Обновить')),
        ],
      ),
    );

    if (shouldUpdate == true) {
      final url = info.urlForCurrentPlatform;
      if (url == null || url.isEmpty) {
        _showError(context, 'Обновление для вашей платформы недоступно');
        return;
      }
      await _downloadAndInstall(context, url);
    }
  }

  Future<void> _downloadAndInstall(BuildContext context, String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;

      Directory saveDir;
      if (Platform.isAndroid) {
        // Используем внешнюю папку Downloads
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getApplicationDocumentsDirectory();
        }
      } else {
        final downloads = await _platform.getDownloadsDirectory();
        saveDir = downloads ?? await getApplicationDocumentsDirectory();
      }

      final fileName = _getFileNameForPlatform(url);
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      Navigator.pop(context); // убираем прогресс

      // Открываем файл
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          _showError(context, 'Не удалось открыть установщик. Файл сохранён в ${file.path}');
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Файл сохранён: ${file.path}')),
          );
        }
      }
    } catch (e, stack) {
      await _logger.error('Update download failed', error: e, stack: stack);
      Navigator.pop(context);
      if (context.mounted) _showError(context, 'Ошибка загрузки обновления');
    }
  }

  String _getFileNameForPlatform(String url) {
    if (Platform.isAndroid) return 'Rizz_update.apk';
    if (Platform.isWindows) return 'Rizz_Setup.exe';
    if (Platform.isLinux) return 'rizz.deb';
    if (Platform.isMacOS) return 'Rizz.dmg';
    return 'Rizz_update';
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}