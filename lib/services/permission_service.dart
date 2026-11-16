import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Единая точка запроса разрешений. Использует permission_handler —
/// надёжно работает на новых Android (в отличие от внутренних запросов
/// сторонних плагинов, которые падали).
class PermissionService {
  PermissionService._();

  /// Доступ к медиатеке (музыка/видео/фото).
  static Future<bool> ensureMedia() async {
    if (!Platform.isAndroid) return true;
    try {
      final statuses = await [
        Permission.audio,
        Permission.videos,
        Permission.photos,
        Permission.storage,
      ].request();
      final audio = statuses[Permission.audio];
      final storage = statuses[Permission.storage];
      final videos = statuses[Permission.videos];
      // Достаточно любого «медийного» разрешения.
      return (audio?.isGranted ?? false) ||
          (videos?.isGranted ?? false) ||
          (storage?.isGranted ?? false) ||
          (statuses[Permission.photos]?.isGranted ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Проверка без запроса.
  static Future<bool> hasMedia() async {
    if (!Platform.isAndroid) return true;
    try {
      final audio = await Permission.audio.status;
      final videos = await Permission.videos.status;
      final storage = await Permission.storage.status;
      return audio.isGranted || videos.isGranted || storage.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Микрофон.
  static Future<bool> ensureMicrophone() async {
    if (!Platform.isAndroid) return true;
    try {
      final s = await Permission.microphone.request();
      return s.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Уведомления (Android 13+) — для foreground-сервиса записи.
  static Future<void> ensureNotifications() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  /// Открыть настройки приложения (если пользователь запретил навсегда).
  static Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }
}