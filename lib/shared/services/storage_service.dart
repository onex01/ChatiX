import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/logger/app_logger.dart'; 

abstract class StorageService {
  Future<String> uploadAvatar(String userId, File file);
  Future<String> uploadFile(String path, File file);
}

class StorageServiceImpl implements StorageService {
  final FirebaseStorage _storage;
  final AppLogger _logger;

  StorageServiceImpl(this._storage, this._logger, AppLogger appLogger);

  @override
  Future<String> uploadAvatar(String userId, File file) async {
    try {
      final ref = _storage.ref().child('avatars/$userId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, stack) {
      await _logger.error('Avatar upload failed', error: e, stack: stack);
      rethrow;
    }
  }

  @override
  Future<String> uploadFile(String path, File file) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, stack) {
      await _logger.error('File upload failed', error: e, stack: stack);
      rethrow;
    }
  }
}