import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeKey = 'selected_theme_mode';

  ThemeMode get themeMode => _themeMode;

  // Конструктор с загрузкой сохранённой темы
  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  // Загрузка темы из SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);

    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = ThemeMode.system;
      }
      notifyListeners(); // Обновляем UI после загрузки
    }
  }

  // Смена темы + сохранение
  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return; // Ничего не делаем, если тема та же

    _themeMode = mode;

    // Сохраняем в SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String themeString;

    switch (mode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeString = 'system';
    }

    await prefs.setString(_themeKey, themeString);

    notifyListeners();
  }
}