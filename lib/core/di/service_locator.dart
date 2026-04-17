// lib/core/di/service_locator.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';
import '../logger/remote_logger.dart';
import '../notification/notification_factory.dart';
import '../notification/notification_service.dart';
import '../platform/platform_factory.dart';
import '../platform/platform_info.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/presence_service.dart';
import '../../shared/services/update_service.dart';
import '../../shared/services/cache_service.dart';
import '../../shared/services/user_cache_service.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/domain/use_cases/send_message_use_case.dart';
import '../../features/chat/domain/use_cases/get_chats_use_case.dart';
import '../../shared/services/message_listener_service.dart';
import '../../shared/services/chunked_file_service.dart';
import '../../shared/services/changelog_service.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Внешние зависимости
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);
  sl.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  sl.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
  sl.registerSingleton<FirebaseStorage>(FirebaseStorage.instance);

  // Платформа
  sl.registerSingleton<PlatformInfo>(getPlatformInfo());

  // Логгер
  sl.registerSingleton<RemoteLogger>(RemoteLogger());
  sl.registerSingleton<AppLogger>(AppLogger(sl<RemoteLogger>()));

  // Уведомления
  sl.registerSingleton<NotificationService>(await createNotificationService());

  // Общие сервисы
  sl.registerLazySingleton<AuthService>(() => AuthServiceImpl(
        sl<FirebaseAuth>(),
        sl<FirebaseFirestore>(),
        sl<AppLogger>(),
      ));
  sl.registerLazySingleton<FirestoreService>(() => FirestoreServiceImpl(
        sl<FirebaseFirestore>(),
        sl<AppLogger>(),
      ));
  sl.registerLazySingleton<StorageService>(() => StorageServiceImpl(
        sl<FirebaseStorage>(),
        sl<PlatformInfo>(),
        sl<AppLogger>(),
      ));
  sl.registerLazySingleton<PresenceService>(() => PresenceService());
  sl.registerLazySingleton<UpdateService>(() => UpdateService());
  sl.registerLazySingleton<MessageFileCache>(() => MessageFileCache());
  sl.registerLazySingleton<UserCacheService>(() => UserCacheService());
  sl.registerLazySingleton<ChangelogService>(() => ChangelogService());
  sl.registerLazySingleton<ChunkedFileService>(() => ChunkedFileService(sl<FirebaseFirestore>()));

  // Репозитории фич
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(
        sl<FirebaseFirestore>(),
        sl<AppLogger>(),
      ));

  // Use Cases
  sl.registerLazySingleton<SendMessageUseCase>(() => SendMessageUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton<GetChatsUseCase>(() => GetChatsUseCase(sl<ChatRepository>()));

  // Уведомлеия
  sl.registerLazySingleton<MessageListenerService>(() => MessageListenerService(
      sl<FirebaseFirestore>(),
      sl<FirebaseAuth>(),
      sl<NotificationService>(),
    ));
}