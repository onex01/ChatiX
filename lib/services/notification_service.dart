import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Обязательный топ-левел обработчик для фона (должен быть вне класса)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 [Background] Получено сообщение: ${message.notification?.title}');
  // FCM сам покажет системное уведомление, если в payload есть поле "notification"
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Инициализация уведомлений (вызывать один раз в main.dart)
  static Future<void> initialize() async {
    // Запрос разрешений
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('🔔 Push notifications разрешены: ${settings.authorizationStatus}');

    // Фон
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Передний план
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Клик по уведомлению (приложение в фоне)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    // Если приложение было полностью закрыто и пользователь нажал уведомление
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpened(initialMessage);
    }

    // Получаем и выводим токен
    final token = await _messaging.getToken();
    print('🔑 FCM Token: $token');
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      Fluttertoast.showToast(
        msg: '${notification.title ?? "Новое сообщение"}: ${notification.body ?? ""}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.blue[700],
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  /// Обработка клика по уведомлению (можно добавить навигацию в чат)
  static void _handleMessageOpened(RemoteMessage message) {
    final data = message.data;
    print('👆 Уведомление открыто! Данные: $data');

    // Пример: если сервер отправляет chatId, можно открыть чат
    if (data['chatId'] != null) {
      print('Переход в чат: ${data['chatId']}');
      // Здесь позже можно добавить глобальную навигацию:
      // navigatorKey.currentState?.pushNamed('/chat', arguments: data['chatId']);
    }
  }

  /// Сохраняем токен в Firestore (вызывать после входа пользователя)
  static Future<void> saveTokenToFirestore(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ FCM Token сохранён для пользователя $userId');
      }
    } catch (e) {
      print('Ошибка сохранения токена: $e');
    }
  }
}