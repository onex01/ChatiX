// ================================================
//  CIRCLE VIDEO SERVICE — Видеокружки как в Telegram
//  Теперь поддерживает до 60 секунд
//  Сильно сжато (480p, 24fps, низкий битрейт)
// ================================================

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:ChatiX/services/cache_service.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'file_converter_service.dart';
import 'message_service.dart';

class CircleVideoService {
  static const int maxDurationSeconds = 20;
  static const String messageType = 'video_circle';

  /// Запись видеокружка + отправка через Base64 в Firestore
  static Future<void> recordAndSendCircle({
    required BuildContext context,
    required String chatId,
    String? replyToMessageId,
    String? repliedMessageText,
  }) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Fluttertoast.showToast(msg: 'Камера не найдена');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final recordedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => _CircleRecorderScreen(
            camera: frontCamera,
            maxDuration: maxDurationSeconds,
          ),
        ),
      );

      if (recordedFile == null) return;

      final size = await recordedFile.length();
      if (size > 800 * 1024) {   // ~800 КБ — безопасный лимит для Base64
        Fluttertoast.showToast(
          msg: 'Видео слишком большое даже после сжатия',
          backgroundColor: Colors.red,
        );
        return;
      }

      Fluttertoast.showToast(msg: 'Конвертация видеокружка...');

      // Читаем байты и конвертируем в Base64
      final bytes = await recordedFile.readAsBytes();
      final base64Data = base64Encode(bytes);

      final fileName = 'circle_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final messageData = {
        'senderId': FirebaseAuth.instance.currentUser!.uid,
        'type': messageType,
        'fileName': fileName,
        'fileExtension': '.mp4',
        'fileSize': size,
        'base64Data': base64Data,           // ← Base64 вместо HEX
        'timestamp': FieldValue.serverTimestamp(),
        'replyToMessageId': replyToMessageId,
        'repliedMessageText': repliedMessageText,
        'isRead': false,
      };

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      await MessageService.updateLastMessage(chatId, '🎥 Кружок');

      Fluttertoast.showToast(msg: 'Видеокружок отправлен!', backgroundColor: Colors.green);
    } catch (e) {
      print('Ошибка видеокружка: $e');
      Fluttertoast.showToast(msg: 'Ошибка: $e', backgroundColor: Colors.red);
    }
  }
}

/// Экран записи кружка (максимальное сжатие)
class _CircleRecorderScreen extends StatefulWidget {
  final CameraDescription camera;
  final int maxDuration;

  const _CircleRecorderScreen({required this.camera, required this.maxDuration});

  @override
  State<_CircleRecorderScreen> createState() => _CircleRecorderScreenState();
}

class _CircleRecorderScreenState extends State<_CircleRecorderScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,     // самое маленькое качество
      enableAudio: true,
      fps: 15,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    await _controller!.startVideoRecording();
    setState(() {
      _isRecording = true;
      _remainingSeconds = widget.maxDuration;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;
    _timer?.cancel();

    final video = await _controller!.stopVideoRecording();
    if (mounted) Navigator.pop(context, File(video.path));
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraPreview(_controller!),

          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.7), width: 5),
              ),
            ),
          ),

          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '$_remainingSeconds',
                style: const TextStyle(fontSize: 64, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.white,
                ),
                child: Center(
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.videocam,
                    color: _isRecording ? Colors.white : Colors.red,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 36),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}