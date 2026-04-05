import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<String> _logLines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rizz_log.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        setState(() {
          _logLines = lines;
          _isLoading = false;
        });
      } else {
        setState(() {
          _logLines = ['Лог-файл не найден'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _logLines = ['Ошибка загрузки лога: $e'];
        _isLoading = false;
      });
    }
  }

  Future<void> _copyLogsToClipboard() async {
    final fullLog = _logLines.join('\n');
    await Clipboard.setData(ClipboardData(text: fullLog));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Логи скопированы в буфер обмена')),
      );
    }
  }

  Future<void> _saveLogsToFile() async {
    try {
      // Для Android 10+ используем Downloads
      // final directory = Platform.isAndroid
      //     ? await getExternalStorageDirectory() // временно, но лучше использовать Downloads
      //     : await getApplicationDocumentsDirectory();
      // Более надёжный способ для Android - сохранить в Downloads
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final file = File('${downloadsDir.path}/rizz_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_logLines.join('\n'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Логи сохранены: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи приложения'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogsToClipboard,
            tooltip: 'Копировать все логи',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _saveLogsToFile,
            tooltip: 'Сохранить в файл',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _logLines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SelectableText(
                    _logLines[index],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}