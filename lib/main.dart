import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  
  // Отслеживаем состояние приложения для статуса онлайн
  AppLifecycleListener? lifecycleListener;
  if (FirebaseAuth.instance.currentUser != null) {
    _setUserOnlineStatus(FirebaseAuth.instance.currentUser!.uid, true);
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
  
  // Слушаем изменения жизненного цикла приложения
  WidgetsBinding.instance.addObserver(
    AppLifecycleObserver(),
  );
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (state == AppLifecycleState.resumed) {
        _setUserOnlineStatus(user.uid, true);
      } else {
        _setUserOnlineStatus(user.uid, false);
      }
    }
  }
}

void _setUserOnlineStatus(String uid, bool isOnline) {
  FirebaseFirestore.instance.collection('users').doc(uid).update({
    'isOnline': isOnline,
    'lastSeen': FieldValue.serverTimestamp(),
  });
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, SettingsProvider>(
      builder: (context, themeProvider, settingsProvider, child) {
        return MaterialApp(
          title: 'ChatiX',
          debugShowCheckedModeBanner: false,
          
          // Светлая тема
          theme: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settingsProvider.accentColor,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontSize: settingsProvider.fontSize),
              bodyMedium: TextStyle(fontSize: settingsProvider.fontSize - 2),
              titleLarge: TextStyle(fontSize: settingsProvider.fontSize + 4),
              titleMedium: TextStyle(fontSize: settingsProvider.fontSize + 2),
            ),
          ),
          
          // Тёмная тема
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settingsProvider.accentColor,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F0F0F),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F0F0F),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontSize: settingsProvider.fontSize),
              bodyMedium: TextStyle(fontSize: settingsProvider.fontSize - 2),
              titleLarge: TextStyle(fontSize: settingsProvider.fontSize + 4),
              titleMedium: TextStyle(fontSize: settingsProvider.fontSize + 2),
            ),
          ),
          
          // Реальная тема, выбранная пользователем
          themeMode: themeProvider.themeMode,
          
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          if (user.emailVerified) {
            return const HomeScreen();
          } else {
            // Почта не подтверждена
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email_outlined, size: 80, color: Colors.orange),
                      const SizedBox(height: 24),
                      const Text(
                        'Подтвердите ваш email',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Письмо отправлено на\n${user.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () async {
                          await user.sendEmailVerification();
                          if (context.mounted) {
                            Fluttertoast.showToast(
                              msg: "Письмо отправлено повторно",
                              backgroundColor: Colors.green,
                              gravity: ToastGravity.BOTTOM,
                            );
                          }
                        },
                        child: const Text('Отправить письмо ещё раз'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Выйти из аккаунта'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        // Не авторизован
        return const AuthScreen();
      },
    );
  }
}