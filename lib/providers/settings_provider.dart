import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String? _wallpaperUrl;
  int? _wallpaperColor;
  List<int>? _wallpaperGradient;
  double _fontSize = 16.0;
  Color _accentColor = Colors.blue;
  int _cacheSize = 100;

  String? get wallpaperUrl => _wallpaperUrl;
  int? get wallpaperColor => _wallpaperColor;
  List<int>? get wallpaperGradient => _wallpaperGradient;
  double get fontSize => _fontSize;
  Color get accentColor => _accentColor;
  int get cacheSize => _cacheSize;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('fontSize') ?? 16.0;
    final accentColorValue = prefs.getInt('accentColor');
    if (accentColorValue != null) {
      _accentColor = Color(accentColorValue);
    }
    _cacheSize = prefs.getInt('cacheSize') ?? 100;
    _wallpaperUrl = prefs.getString('wallpaperUrl');
    _wallpaperColor = prefs.getInt('wallpaperColor');
    final gradientStr = prefs.getString('wallpaperGradient');
    if (gradientStr != null) {
      final parts = gradientStr.split(',');
      if (parts.length == 2) {
        _wallpaperGradient = [int.parse(parts[0]), int.parse(parts[1])];
      }
    }
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColor', color.value);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
    notifyListeners();
  }

  Future<void> setWallpaper(String? url) async {
    _wallpaperUrl = url;
    _wallpaperColor = null;
    _wallpaperGradient = null;
    final prefs = await SharedPreferences.getInstance();
    if (url != null) {
      await prefs.setString('wallpaperUrl', url);
      await prefs.remove('wallpaperColor');
      await prefs.remove('wallpaperGradient');
    } else {
      await prefs.remove('wallpaperUrl');
    }
    notifyListeners();
  }

  Future<void> setWallpaperColor(int color) async {
    _wallpaperUrl = null;
    _wallpaperGradient = null;
    _wallpaperColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallpaperUrl');
    await prefs.remove('wallpaperGradient');
    await prefs.setInt('wallpaperColor', color);
    notifyListeners();
  }

  Future<void> setWallpaperGradient(List<int> colors) async {
    _wallpaperUrl = null;
    _wallpaperColor = null;
    _wallpaperGradient = colors;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallpaperUrl');
    await prefs.remove('wallpaperColor');
    await prefs.setString('wallpaperGradient', colors.join(','));
    notifyListeners();
  }

  Future<void> clearWallpaper() async {
    _wallpaperUrl = null;
    _wallpaperColor = null;
    _wallpaperGradient = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallpaperUrl');
    await prefs.remove('wallpaperColor');
    await prefs.remove('wallpaperGradient');
    notifyListeners();
  }

  Future<void> setCacheSize(int size) async {
    _cacheSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cacheSize', size);
    notifyListeners();
  }
}