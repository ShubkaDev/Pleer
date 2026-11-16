import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'permission_service.dart';
import 'recorded_media_store.dart';

/// Запись экрана на Android через MediaProjection.
/// Реализация нативна: канал multitool.screen, события — multitool.screen/events.
class ScreenRecorderController extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('multitool.screen');
  static const MethodChannel _overlay = MethodChannel('multitool.overlay');

  StreamSubscription? _eventsSub;
  bool _listening = false;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;
  Timer? _timer;

  bool _bubbleVisible = false;
  bool get bubbleVisible => _bubbleVisible;

  String? _lastSavedPath;
  String? get lastSavedPath => _lastSavedPath;

  String? _error;
  String? get error => _error;

  bool get isSupported => Platform.isAndroid;

  /// Есть ли разрешение «Поверх других приложений» (кружок остановки).
  Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _overlay.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Открывает системные настройки для выдачи права на кружок.
  Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _overlay.invokeMethod('requestOverlay');
    } catch (_) {}
  }

  Future<void> start() async {
    if (!isSupported) {
      throw StateError('Запись экрана доступна только на Android');
    }
    _error = null;
    _lastSavedPath = null;
    // Уведомления нужны для foreground-сервиса записи (Android 13+).
    await PermissionService.ensureNotifications();

    _listenEvents();

    try {
      final started = await _channel.invokeMethod<bool>('start');
      if (started != true) {
        throw StateError('Не удалось запустить запись экрана');
      }
      _isRecording = true;
      _bubbleVisible = false;
      _duration = Duration.zero;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        _duration += const Duration(seconds: 1);
        notifyListeners();
      });
      notifyListeners();
    } on MissingPluginException {
      throw StateError('Запись экрана не поддерживается на этом устройстве');
    } catch (e) {
      throw StateError('Ошибка запуска записи экрана: $e');
    }
  }

  void _listenEvents() {
    if (_listening) return;
    _listening = true;
    try {
      _eventsSub = const EventChannel('multitool.screen/events')
          .receiveBroadcastStream()
          .listen(_handleEvent, onError: (_) {});
    } catch (_) {}
  }

  void _handleEvent(dynamic raw) {
    if (raw is! Map) return;
    final type = raw['type'] as String?;
    final path = raw['path'] as String?;
    final message = raw['message'] as String?;
    final bubble = raw['bubble'] == true;

    switch (type) {
      case 'started':
        _isRecording = true;
        _bubbleVisible = bubble;
        _error = null;
        break;
      case 'stopped':
        _isRecording = false;
        _bubbleVisible = false;
        _timer?.cancel();
        if (path != null && path.isNotEmpty) {
          _lastSavedPath = path;
          RecordedMediaStore.add(path);
        }
        break;
      case 'error':
        _isRecording = false;
        _bubbleVisible = false;
        _timer?.cancel();
        _error = message ?? 'Ошибка записи экрана';
        break;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
    // Реальное состояние придёт событием 'stopped' от сервиса;
    // страхуемся, чтобы интерфейс не завис, если сервис уже умер.
    if (_isRecording) {
      _isRecording = false;
      _timer?.cancel();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }
}
