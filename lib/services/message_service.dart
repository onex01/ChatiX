import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';  // ← ДОБАВИТЬ ЭТУ СТРОКУ
import 'package:fluttertoast/fluttertoast.dart';
import 'file_converter_service.dart';

class MessageService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Отправка текстового сообщения
  static Future<void> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    String? repliedMessageText,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      final messageData = {
        'senderId': currentUser.uid,
        'type': 'text',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'replyToMessageId': replyToMessageId,
        'repliedMessageText': repliedMessageText,
        'isRead': false,
        'isEdited': false,
        'isDeleted': false,
      };

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      await _updateLastMessage(chatId, text);
      
      debugPrint('✅ Текстовое сообщение отправлено');
    } catch (e) {
      debugPrint('❌ Ошибка отправки текста: $e');
      rethrow;
    }
  }

  /// Отправка изображения (через hex)
  static Future<void> sendImageMessage({
    required String chatId,
    required XFile imageFile,
    String? replyToMessageId,
    String? repliedMessageText,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      final file = File(imageFile.path);
      
      if (!await file.exists()) {
        throw Exception('Файл не существует');
      }
      
      final fileSize = await file.length();
      debugPrint('📷 Размер файла: ${fileSize ~/ 1024} KB');
      
      if (fileSize > FileConverterService.maxFileSize) {
        Fluttertoast.showToast(
          msg: 'Файл слишком большой (макс ${FileConverterService.maxFileSize ~/ 1024} KB)',
          backgroundColor: Colors.red,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
      
      Fluttertoast.showToast(
        msg: 'Конвертация изображения...',
        gravity: ToastGravity.BOTTOM,
      );
      
      final hexData = await FileConverterService.fileToHex(file);
      final fileName = p.basename(imageFile.path);
      final fileExtension = p.extension(file.path).toLowerCase();
      
      debugPrint('📝 Изображение сконвертировано в hex, длина: ${hexData.length} символов');
      
      final messageData = {
        'senderId': currentUser.uid,
        'type': 'image_hex',
        'fileName': fileName,
        'fileExtension': fileExtension,
        'fileSize': fileSize,
        'hexData': hexData,
        'timestamp': FieldValue.serverTimestamp(),
        'replyToMessageId': replyToMessageId,
        'repliedMessageText': repliedMessageText,
        'isRead': false,
      };

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
          
      debugPrint('✅ Изображение отправлено через hex');
      Fluttertoast.showToast(
        msg: 'Изображение отправлено!',
        backgroundColor: Colors.green,
        gravity: ToastGravity.BOTTOM,
      );

      await _updateLastMessage(chatId, '📷 Фото');
      
    } catch (e) {
      debugPrint('❌ Ошибка отправки изображения: $e');
      Fluttertoast.showToast(
        msg: 'Ошибка отправки: $e',
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
      );
      rethrow;
    }
  }

  /// Отправка файла (через hex)
  static Future<void> sendFileMessage({
    required String chatId,
    required File file,
    String? replyToMessageId,
    String? repliedMessageText,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      if (!await file.exists()) {
        throw Exception('Файл не существует');
      }
      
      final fileName = p.basename(file.path);
      final fileExtension = p.extension(file.path).toLowerCase();
      final fileSize = await file.length();
      
      debugPrint('📎 Размер файла: ${fileSize ~/ 1024} KB');
      
      if (fileSize > FileConverterService.maxFileSize) {
        Fluttertoast.showToast(
          msg: 'Файл слишком большой (макс ${FileConverterService.maxFileSize ~/ 1024} KB)',
          backgroundColor: Colors.red,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
      
      Fluttertoast.showToast(
        msg: 'Конвертация файла...',
        gravity: ToastGravity.BOTTOM,
      );
      
      final hexData = await FileConverterService.fileToHex(file);
      
      debugPrint('📝 Файл сконвертирован в hex, длина: ${hexData.length} символов');
      
      final messageData = {
        'senderId': currentUser.uid,
        'type': 'file_hex',
        'fileName': fileName,
        'fileExtension': fileExtension,
        'fileSize': fileSize,
        'hexData': hexData,
        'timestamp': FieldValue.serverTimestamp(),
        'replyToMessageId': replyToMessageId,
        'repliedMessageText': repliedMessageText,
        'isRead': false,
      };

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
          
      debugPrint('✅ Файл отправлен через hex');
      Fluttertoast.showToast(
        msg: 'Файл отправлен!',
        backgroundColor: Colors.green,
        gravity: ToastGravity.BOTTOM,
      );

      await _updateLastMessage(chatId, '📎 Файл: $fileName');
      
    } catch (e) {
      debugPrint('❌ Ошибка отправки файла: $e');
      Fluttertoast.showToast(
        msg: 'Ошибка отправки: $e',
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
      );
      rethrow;
    }
  }

  /// Получение файла из hex сообщения
  static Future<File?> getFileFromMessage(Map<String, dynamic> messageData) async {
    try {
      final hexData = messageData['hexData'];
      final fileName = messageData['fileName'];
      
      if (hexData == null || fileName == null) return null;
      
      return await FileConverterService.hexToFile(hexData, fileName);
    } catch (e) {
      debugPrint('❌ Ошибка получения файла из сообщения: $e');
      return null;
    }
  }

  /// Выбор и отправка файла
  static Future<void> pickAndSendFile({
    required String chatId,
    String? replyToMessageId,
    String? repliedMessageText,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      
      final file = File(result.files.first.path!);
      await sendFileMessage(
        chatId: chatId,
        file: file,
        replyToMessageId: replyToMessageId,
        repliedMessageText: repliedMessageText,
      );
    } catch (e) {
      debugPrint('Ошибка выбора файла: $e');
      rethrow;
    }
  }

  /// Выбор и отправка изображения
  static Future<void> pickAndSendImage({
    required String chatId,
    String? replyToMessageId,
    String? repliedMessageText,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (pickedFile == null) return;

      await sendImageMessage(
        chatId: chatId,
        imageFile: pickedFile,
        replyToMessageId: replyToMessageId,
        repliedMessageText: repliedMessageText,
      );
    } catch (e) {
      debugPrint('Ошибка выбора изображения: $e');
      rethrow;
    }
  }

  /// Снять фото и отправить
  static Future<void> takeAndSendPhoto({
    required String chatId,
    String? replyToMessageId,
    String? repliedMessageText,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (pickedFile == null) return;

      await sendImageMessage(
        chatId: chatId,
        imageFile: pickedFile,
        replyToMessageId: replyToMessageId,
        repliedMessageText: repliedMessageText,
      );
    } catch (e) {
      debugPrint('Ошибка съемки фото: $e');
      rethrow;
    }
  }

  static Future<void> _updateLastMessage(String chatId, String lastMessageText) async {
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': lastMessageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }
}