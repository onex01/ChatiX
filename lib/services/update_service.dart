import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../version.dart';

class UpdateService {
  static const String baseUrl = 'https://rizz.onex01.ru/';
  
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/version.json'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final currentVersion = AppVersion.version;
        
        print('Current version: $currentVersion, Latest: $latestVersion');
        
        if (_isNewerVersion(latestVersion, currentVersion)) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('Error checking updates: $e');
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
      return false;
    }
  }
  
  static Future<void> showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo) async {
    // Создаем отдельный контекст для диалога
    Navigator.of(context);
    
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Доступно обновление!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Доступна новая версия приложения!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Размер: ${(updateInfo['fileSize'] / 1024 / 1024).toStringAsFixed(1)} МБ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
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
              child: const Text(
                'Позже',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Обновить сейчас'),
            ),
          ],
        );
      },
    );
    
    if (shouldUpdate == true && updateInfo['downloadUrl'] != null) {
      // Показываем индикатор загрузки
      _showDownloadProgress(context, updateInfo['downloadUrl']);
    }
  }
  
  static Future<void> _showDownloadProgress(BuildContext context, String downloadUrl) async {
    // Создаем диалог с прогрессом
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Загрузка обновления...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Пожалуйста, подождите',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
    
    try {
      // Загружаем файл
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory!.path}/Rizz_update.apk';
      final file = File(filePath);
      
      final response = await http.get(Uri.parse(downloadUrl));
      await file.writeAsBytes(response.bodyBytes);
      
      // Закрываем диалог прогресса
      if (context.mounted) {
        Navigator.of(context).pop(); // Закрываем диалог прогресса
      }
      
      // Показываем сообщение об успехе
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обновление загружено. Установка...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Открываем APK для установки
      await OpenFile.open(filePath);
      
    } catch (e) {
      // Закрываем диалог прогресса при ошибке
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Показываем сообщение об ошибке
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки обновления: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('Error downloading update: $e');
    }
  }
}