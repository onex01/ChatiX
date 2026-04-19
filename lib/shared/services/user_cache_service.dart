import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_converter_service.dart';

class UserCacheService {
  static const String _nicknamePrefix = 'user_nickname_';
  static const String _usernamePrefix = 'user_username_';
  static const String _photoPrefix = 'user_photo_';
  static const String _avatarHexPrefix = 'avatar_hex_';

  final Map<String, String?> _nicknames = {};
  final Map<String, String?> _usernames = {};
  final Map<String, String?> _photoUrls = {};
  final Map<String, String?> _avatarHexs = {};

  Future<void> cacheUser(String uid, String? nickname, String? photoUrl, [String? username]) async {
    final prefs = await SharedPreferences.getInstance();

    if (nickname != null) {
      _nicknames[uid] = nickname;
      await prefs.setString('$_nicknamePrefix$uid', nickname);
    }
    if (username != null) {
      _usernames[uid] = username;
      await prefs.setString('$_usernamePrefix$uid', username);
    }
    if (photoUrl != null) {
      _photoUrls[uid] = photoUrl;
      await prefs.setString('$_photoPrefix$uid', photoUrl);
    }
  }

  Future<void> cacheAvatarHex(String uid, String hexData) async {
    final prefs = await SharedPreferences.getInstance();
    _avatarHexs[uid] = hexData;
    await prefs.setString('$_avatarHexPrefix$uid', hexData);
  }

  String? getNickname(String uid) => _nicknames[uid];
  String? getUsername(String uid) => _usernames[uid];
  String? getPhotoUrl(String uid) => _photoUrls[uid];
  String? getAvatarHex(String uid) => _avatarHexs[uid];

  Future<File?> getAvatarFile(String uid) async {
    final hex = getAvatarHex(uid);
    if (hex == null) return null;
    return await FileConverterService.hexToFile(hex, 'avatar_$uid.jpg');
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_nicknamePrefix) || key.startsWith(_avatarHexPrefix)) {
        await prefs.remove(key);
      }
    }
    _nicknames.clear();
    _usernames.clear();
    _photoUrls.clear();
    _avatarHexs.clear();
  }

  Future<void> invalidateUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_nicknamePrefix$uid');
    await prefs.remove('$_avatarHexPrefix$uid');
    _nicknames.remove(uid);
    _avatarHexs.remove(uid);
  }
}