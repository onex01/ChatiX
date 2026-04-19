import 'package:Rizz/shared/services/audio_player_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/logger/app_logger.dart';
import 'core/notification/notification_service.dart';
import 'shared/services/message_listener_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await setupServiceLocator();

  final logger = GetIt.I<AppLogger>();
  await logger.init();

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    if (uri.scheme == 'rizz' && uri.host == 'profile') {
      uri.pathSegments.first.replaceFirst('@', '');
      // Навигация к профилю пользователя по username
      // (предварительно найти uid по username)
    }
  });

  // Глобальный перехват ошибок Flutter
  FlutterError.onError = (details) {
    logger.error(
      'Flutter error: ${details.exception}',
      error: details.exception,
      stack: details.stack,
    );
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
  };

  // Перехват необработанных асинхронных ошибок
  PlatformDispatcher.instance.onError = (error, stack) {
    // Выводим в консоль для немедленной видимости при отладке
    debugPrint('!!! PlatformDispatcher caught error: $error');
    debugPrint('$stack');
    logger.error('Uncaught async error', error: error, stack: stack);
    return true;
  };

  // Инициализация уведомлений
  final notificationService = GetIt.I<NotificationService>();
  await notificationService.initialize();

  // Запуск слушателя сообщений для фоновых уведомлений
  final messageListener = GetIt.I<MessageListenerService>();
  messageListener.startListening();

  // В вашем initServices()
GetIt.I.registerSingleton<AudioPlayerService>(AudioPlayerService());
await GetIt.I<AudioPlayerService>().init();   // ← обязательно!

  runApp(const RizzApp());
}