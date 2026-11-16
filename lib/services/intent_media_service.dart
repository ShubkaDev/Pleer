import 'dart:io';

import 'package:flutter/services.dart';

/// Приём файлов, открытых из проводника/других приложений (Android).
/// Поступает uri (content:// или file://), тип (audio/* или video/*) и имя.
class IntentMediaService {
  IntentMediaService._();

  static const MethodChannel _method = MethodChannel('multitool.intent');
  static const EventChannel _events = EventChannel('multitool.intent/events');

  static void Function(Map<String, String> media)? _handler;

  static Future<void> init(void Function(Map<String, String> media) handler) async {
    _handler = handler;
    if (!Platform.isAndroid) return;
    try {
      final initial = await _method.invokeMapMethod<String, String>('getInitialMedia');
      if (initial != null && initial['uri'] != null) {
        handler(initial);
      }
    } catch (_) {}
    try {
      _events.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final map = <String, String>{};
          event.forEach((k, v) => map[k.toString()] = v.toString());
          _handler?.call(map);
        }
      }, onError: (_) {});
    } catch (_) {}
  }
}