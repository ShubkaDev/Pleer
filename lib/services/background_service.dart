import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Управление фоном приложения: градиент по умолчанию или одна из картинок.
class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  static const List<String> bgAssets = [
    'assets/backgrounds/bg1.jpg',
    'assets/backgrounds/bg2.jpg',
    'assets/backgrounds/bg3.jpg',
    'assets/backgrounds/bg4.jpg',
    'assets/backgrounds/bg5.jpg',
  ];

  // Случайная или индексированная, null = градиент.
  String? _selected;
  bool _isDark = true;

  String? get selected => _selected;
  bool get isGradient => _selected == null;
  bool get isDark => _isDark;

  static const _gradientColors = [
    Color(0xFF0F208D),
    Color(0xFF5716FF),
    Color(0xFFA62AFF),
    Color(0xFFE439B3),
  ];

  /// Градиент по умолчанию.
  static const LinearGradient defaultGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F208D), Color(0xFF5716FF), Color(0xFFA62AFF), Color(0xFFE439B3)],
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString('background');
    _isDark = prefs.getBool('bg_isDark') ?? true;
  }

  /// Применить фон по индексу картинки (0..4) или градиент (null).
  Future<void> setBackground(String? value) async {
    _selected = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('background');
    } else {
      await prefs.setString('background', value);
    }
  }

  Future<void> setDark(bool dark) async {
    _isDark = dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bg_isDark', dark);
  }
}