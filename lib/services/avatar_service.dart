import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class AvatarService {
  static const int maxAvatarSize = 500 * 1024; // 500 KB
  
  static Future<String?> pickAndCropAvatar() async {
    try {
      // Выбираем изображение из галереи
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      
      if (pickedFile == null) return null;
      
      // Обрезаем изображение
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Редактор аватара',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Редактор аватара',
            minimumAspectRatio: 1.0,
          ),
        ],
      );
      
      if (croppedFile == null) return null;
      
      // Конвертируем в hex
      final File file = File(croppedFile.path);
      final bytes = await file.readAsBytes();
      
      // Проверяем размер
      if (bytes.length > maxAvatarSize) {
        throw Exception('Аватар слишком большой (макс 500KB)');
      }
      
      final hexString = _bytesToHex(bytes);
      
      // Сохраняем в Firestore
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'avatarHex': hexString,
        'avatarUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      return hexString;
    } catch (e) {
      print('Ошибка при обработке аватара: $e');
      return null;
    }
  }
  
  static Future<File?> hexToAvatarFile(String hexData) async {
    try {
      final bytes = _hexToBytes(hexData);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('Ошибка конвертации hex в файл: $e');
      return null;
    }
  }
  
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
  
  static List<int> _hexToBytes(String hex) {
    final List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      final byte = int.parse(hex.substring(i, i + 2), radix: 16);
      bytes.add(byte);
    }
    return bytes;
  }
}