import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Список видео, записанных самим приложением (запись экрана).
///
/// Хранится на устройстве, чтобы записи были видны в разделе «Видео» даже
/// если доступ к медиатеке не выдан: приложение владеет этими файлами.
class RecordedMediaStore {
  RecordedMediaStore._();

  static const _key = 'recorded_videos_v1';

  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const <String>[];
      final result = <Map<String, dynamic>>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) result.add(decoded);
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> add(String uri, {String? title}) async {
    if (uri.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await load();
      list.removeWhere((m) => m['uri'] == uri);
      list.insert(0, {
        'uri': uri,
        'title': title ?? _defaultTitle(),
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      final encoded = list.take(200).map(jsonEncode).toList();
      await prefs.setStringList(_key, encoded);
    } catch (_) {}
  }

  static Future<void> remove(String uri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await load();
      list.removeWhere((m) => m['uri'] == uri);
      await prefs.setStringList(_key, list.map(jsonEncode).toList());
    } catch (_) {}
  }

  static String _defaultTitle() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Запись экрана ${two(now.day)}.${two(now.month)}.${now.year} '
        '${two(now.hour)}:${two(now.minute)}';
  }
}
