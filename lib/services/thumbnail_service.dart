import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Кэш кадров-превью для видео. Кадр запрашивается у Android один раз
/// (MediaStore), дальше отдаётся из памяти — сетка не мигает при прокрутке.
class ThumbnailService {
  ThumbnailService._();

  static const MethodChannel _channel = MethodChannel('multitool.thumbs');
  static final Map<String, Uint8List?> _cache = {};

  /// Уже загруженный кадр или null, если запрос ещё не выполнялся.
  static Uint8List? cached(String uri) => _cache[uri];

  static bool knows(String uri) => _cache.containsKey(uri);

  static Future<Uint8List?> videoThumb(String uri) async {
    if (uri.isEmpty) return null;
    if (_cache.containsKey(uri)) return _cache[uri];
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'videoThumb',
        {'uri': uri},
      );
      _cache[uri] = bytes;
      return bytes;
    } catch (_) {
      _cache[uri] = null;
      return null;
    }
  }

  static void clear() => _cache.clear();
}
