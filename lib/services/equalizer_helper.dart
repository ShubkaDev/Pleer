import 'dart:io';

import 'package:flutter/services.dart';

/// Обёртка над нативным Android AudioEffect (равнобортовый 5-полосный EQ
/// и Bass Boost). На Windows/десктопе не применяется (возвращает false).
class EqualizerHelper {
  static const MethodChannel _channel =
      MethodChannel('multitool.equalizer');

  bool get isSupported => Platform.isAndroid;

  Future<bool> enable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod('enable') == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBandLevel(int band, double gainDb) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setBandLevel', {
        'band': band,
        'gain': gainDb,
      });
    } catch (_) {}
  }

  Future<void> setBassBoost(int strengthPercent) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setBassBoost', {
        'strength': strengthPercent,
      });
    } catch (_) {}
  }

  Future<void> release() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('release');
    } catch (_) {}
  }
}