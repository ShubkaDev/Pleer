import 'dart:io';

import 'package:flutter/services.dart';

/// Обновление нативного виджета на главном экране (Android).
class WidgetService {
  WidgetService._();
  static const MethodChannel _channel = MethodChannel('multitool.widget');

  static Future<void> update({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('update', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
      });
    } catch (_) {}
  }

  static Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('refresh');
    } catch (_) {}
  }
}