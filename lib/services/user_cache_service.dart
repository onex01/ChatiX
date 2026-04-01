import 'package:shared_preferences/shared_preferences.dart';

class UserCacheService {
  static final UserCacheService _instance = UserCacheService._internal();
  factory UserCacheService() => _instance;
  UserCacheService._internal();

  static const String _nicknamePrefix = 'user_nickname_';
  static const String _photoPrefix = 'user_photo_';

  Future<void> cacheUser(String uid, String? nickname, String? photoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (nickname != null) {
      await prefs.setString('$_nicknamePrefix$uid', nickname);
    }
    if (photoUrl != null) {
      await prefs.setString('$_photoPrefix$uid', photoUrl);
    } else {
      await prefs.remove('$_photoPrefix$uid');
    }
  }

  String? getNickname(String uid) {
    // Для мгновенного чтения используем SharedPreferences.getInstance() синхронно
    // (в реальном приложении лучше сделать async, но для скорости мы берём из памяти)
    // Здесь используется простой подход — читаем из SharedPreferences каждый раз
    // (SharedPreferences очень быстрый)
    return null; // будет переписано ниже
  }

  String? getPhotoUrl(String uid) {
    return null; // будет переписано ниже
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_nicknamePrefix) || key.startsWith(_photoPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}

// Реализация getNickname / getPhotoUrl (синхронная версия)
extension UserCacheServiceSync on UserCacheService {
  String? getNickname(String uid) {
    // Этот метод вызывается часто, поэтому делаем его быстрым
    // (SharedPreferences.getInstance() кэшируется внутри)
    try {
      final prefs = SharedPreferences.getInstance() as SharedPreferences;
      return prefs.getString('$UserCacheService._nicknamePrefix$uid');
    } catch (_) {
      return null;
    }
  }

  String? getPhotoUrl(String uid) {
    try {
      final prefs = SharedPreferences.getInstance() as SharedPreferences;
      return prefs.getString('$UserCacheService._photoPrefix$uid');
    } catch (_) {
      return null;
    }
  }
}