import 'dart:io';

import 'package:flutter/services.dart';

class TrackTags {
  final String title;
  final String artist;
  final String album;
  final String? artworkPath;

  TrackTags({
    required this.title,
    required this.artist,
    required this.album,
    this.artworkPath,
  });
}

/// Чтение и редактирование ID3-тегов (Pro). На Android реализуется через
/// нативный канал (Android MediaMetadataRetriever + Apache Commons текст),
/// на Windows — через id3reader. Здесь обёртка.
class TagsService {
  static const MethodChannel _channel =
      MethodChannel('multitool.tags');

  bool get isSupported => Platform.isAndroid;

  /// Прочитать теги из файла по пути.
  Future<TrackTags?> read(String filePath) async {
    if (!isSupported) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('read', {
        'path': filePath,
      });
      if (res == null) return null;
      return TrackTags(
        title: (res['title'] ?? '') as String,
        artist: (res['artist'] ?? '') as String,
        album: (res['album'] ?? '') as String,
        artworkPath: res['artwork'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Записать теги в файл (только Android 10+ с флагом специальный доступ,
  /// либо на старых версиях).
  Future<bool> write(
    String filePath, {
    String? title,
    String? artist,
    String? album,
  }) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'write',
            {
              'path': filePath,
              'title': title,
              'artist': artist,
              'album': album,
            },
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}