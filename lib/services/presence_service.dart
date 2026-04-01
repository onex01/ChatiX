import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Инициализация присутствия пользователя (вызывать один раз после входа в аккаунт)
  static Future<void> initPresence() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    // Устанавливаем онлайн
    await userRef.update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });

    // При отключении приложения/интернета автоматически ставим оффлайн
    await userRef.set({'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    // onDisconnect работает через Realtime Database (рекомендуется Firebase Realtime DB)
    // Если у тебя нет Realtime DB — можно использовать Cloud Functions или таймер, но для простоты оставляем Firestore + manual goOffline в dispose
  }

  /// Вызывать при выходе из приложения (в logout или dispose главного экрана)
  static Future<void> goOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}