import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Обязательный топ-левел обработчик для фона
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 [Background] Получено сообщение: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  /// Инициализация уведомлений
  static Future<void> initialize() async {
    // Настройка локальных уведомлений для Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(initSettings);

    // Запрос разрешений
    final notificationSettings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('🔔 Push notifications разрешены: ${notificationSettings.authorizationStatus}');

    // Фон
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Передний план
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Клик по уведомлению
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    // Получаем токен
    final token = await _messaging.getToken();
    print('🔑 FCM Token: $token');
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      // Показываем локальное уведомление
      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notification.title ?? 'Новое сообщение',
        notification.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'chatix_channel',
            'ChatiX Уведомления',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  static void _handleMessageOpened(RemoteMessage message) {
    final data = message.data;
    print('👆 Уведомление открыто! Данные: $data');
    
    // TODO: Добавить навигацию в чат
    if (data['chatId'] != null) {
      print('Переход в чат: ${data['chatId']}');
    }
  }

  /// Сохраняем токен в Firestore
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