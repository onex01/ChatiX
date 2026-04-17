import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class MobileNotificationService implements NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageOpenedController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  @override
  Stream<Map<String, dynamic>> get onMessageOpenedApp => _messageOpenedController.stream;

  @override
  Future<void> initialize() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'rizz_channel',
      'Rizz Notifications',
      importance: Importance.high,
      description: 'Notifications for new messages',
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher_blue_white');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(initSettings);

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('FCM permissions not granted');
      return;
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _messageController.add(message.data);
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'rizz_channel',
              'Rizz Notifications',
              channelDescription: 'Notifications for new messages',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _messageOpenedController.add(message.data);
    });

    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _messageOpenedController.add(initialMessage.data);
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      0,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rizz_channel',
          'Rizz Notifications',
          channelDescription: 'Notifications for new messages',
          importance: Importance.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String content,
    required String messageType,
    String? senderPhotoUrl,
  }) async {
    String body;
    switch (messageType) {
      case 'image_hex':
      case 'image':
        body = '📷 Фотография';
        break;
      case 'file_hex':
      case 'file':
        body = '📎 Файл';
        break;
      case 'voice':
        body = '🎤 Голосовое сообщение';
        break;
      case 'video_circle':
      case 'video':
        body = '🎥 Видео';
        break;
      default:
        body = content.length > 100 ? '${content.substring(0, 100)}…' : content;
    }

    // Действия для Android
    final List<AndroidNotificationAction> actions = [
      AndroidNotificationAction(
        'read_action',
        'Прочитать',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'reply_action',
        'Ответить',
        showsUserInterface: true,
        inputs: [
          AndroidNotificationActionInput(label: 'Ответ...'),
        ],
      ),
    ];

    await _localNotifications.show(
      chatId.hashCode,
      senderName,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rizz_channel',
          'Rizz Notifications',
          channelDescription: 'Notifications for new messages',
          importance: Importance.high,
          priority: Priority.high,
          actions: actions,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'chatId': chatId}),
    );
  }
}