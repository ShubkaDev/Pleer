import 'dart:io';
import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

import '../data/models.dart';
import 'permission_service.dart';

class LibraryService {
  final OnAudioQuery _query = OnAudioQuery();

  static const _videoExts = {'.mp4', '.mkv', '.3gp', '.webm', '.avi', '.mov', '.ts'};
  static const _audioExts = {'.mp3', '.m4a', '.aac', '.wav', '.flac', '.ogg', '.opus', '.wma', '.m4b'};

  Future<bool> ensurePermission() async {
    // Используем permission_handler: внутренние запросы on_audio_query
    // падали на новых Android при показе диалога разрешений.
    return PermissionService.ensureMedia();
  }

  /// Сканирует все песни на устройстве.
  /// Android — через MediaStore; Windows/десктоп — обход папок.
  Future<List<Track>> scanTracks() async {
    if (!Platform.isAndroid) {
      return _scanTracksDesktop();
    }
    final songs = await _query.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
    );
    return songs.map((s) {
      return Track(
        id: s.id,
        data: s.data,
        title: s.title,
        artist: s.artist ?? '',
        album: s.album ?? '',
        durationMs: s.duration ?? 0,
        dateAdded: s.dateAdded ?? 0,
      );
    }).toList();
  }

  /// Обход папок с музыкой на десктопе (Windows/Linux/macOS).
  Future<List<Track>> _scanTracksDesktop() async {
    final result = <Track>[];
    for (final root in _musicRoots()) {
      try {
        await _walkAudio(root, result);
      } catch (_) {}
    }
    return result;
  }

  List<Directory> _musicRoots() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isEmpty) return [];
    return [
      Directory('$home/Music'),
      Directory('$home/Downloads'),
      Directory('$home/Videos'),
    ].where((d) => d.existsSync()).toList();
  }

  Future<void> _walkAudio(Directory dir, List<Track> out) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        try {
          if (entity is Directory) {
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last
                : '';
            if (_systemFolder(name)) continue;
            await _walkAudio(entity, out);
          } else if (entity is File) {
            final lower = entity.path.toLowerCase();
            if (_audioExts.any(lower.endsWith)) {
              final stat = entity.statSync();
              final fileName = entity.uri.pathSegments.last;
              out.add(Track(
                id: entity.path.hashCode,
                data: entity.path,
                title: fileName,
                artist: '',
                album: '',
                durationMs: 0,
                dateAdded: stat.modified.millisecondsSinceEpoch ~/ 1000,
              ));
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Сканирует видеофайлы рекурсивно по доступным папкам.
  /// (on_audio_query 2.x не поддерживает видео напрямую.)
  Future<List<VideoItem>> scanVideos() async {
    final results = <VideoItem>[];
    // На Android ищем в стандартных каталогах мультимедиа.
    final roots = _videoRoots();
    for (final root in roots) {
      try {
        await _walk(root, results);
      } catch (_) {}
    }
    return results;
  }

  List<Directory> _videoRoots() {
    final list = <Directory>[];
    if (Platform.isAndroid) {
      final exts = _getExternalMediaDirs();
      for (final e in exts) {
        if (e != null) list.add(Directory(e));
      }
      // fallback
      try {
        list.add(Directory('/storage/emulated/0/Movies'));
        list.add(Directory('/storage/emulated/0/DCIM'));
        list.add(Directory('/storage/emulated/0/Download'));
      } catch (_) {}
    } else {
      // Desktop: домашняя папка с видео/фильмами
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      if (home.isNotEmpty) {
        list.add(Directory('$home/Videos'));
        list.add(Directory('$home/Movies'));
      }
    }
    return list;
  }

  List<String?> _getExternalMediaDirs() {
    // Пытаемся получить из стандартных путей без плагина.
    return [
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/Download',
    ];
  }

  Future<void> _walk(Directory dir, List<VideoItem> out) async {
    // Ограничение глубины/объёма: не уходим в системные папки.
    try {
      await for (final entity in dir.list(followLinks: false)) {
        try {
          if (entity is Directory) {
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last
                : '';
            if (_systemFolder(name)) continue;
            await _walk(entity, out);
          } else if (entity is File) {
            final lower = entity.path.toLowerCase();
            if (_videoExts.any(lower.endsWith)) {
              final stat = entity.statSync();
              final id = entity.path.hashCode;
              out.add(VideoItem(
                id: id,
                data: entity.path,
                title: entity.uri.pathSegments.last,
                album: '',
                artist: '',
                durationMs: 0,
                size: stat.size,
                dateAdded: stat.modified.millisecondsSinceEpoch ~/ 1000,
              ));
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  bool _systemFolder(String name) {
    const sys = ['Android', 'data', 'obb', 'cache', 'app', 'system', 'lost+found'];
    return sys.contains(name);
  }

  // Кэш обложек: без него FutureBuilder перезапрашивает арт на каждой
  // перерисовке списка, и иконки треков «мерцают».
  final Map<int, Uint8List?> _artCache = {};
  final Map<int, Future<Uint8List?>> _artPending = {};

  /// Сбрасывает кэш обложек (после пересканирования библиотеки).
  void clearArtCache() {
    _artCache.clear();
    _artPending.clear();
  }

  /// Возвращает байты обложки для трека по его MediaStore-ID.
  /// Результат кэшируется, повторные вызовы отдают тот же объект.
  Future<Uint8List?> albumArt(int trackId) {
    if (_artCache.containsKey(trackId)) {
      return Future.value(_artCache[trackId]);
    }
    return _artPending[trackId] ??= _loadArt(trackId);
  }

  Future<Uint8List?> _loadArt(int trackId) async {
    Uint8List? bytes;
    try {
      bytes = await _query.queryArtwork(
        trackId,
        ArtworkType.AUDIO,
        size: 512,
      );
    } catch (_) {
      bytes = null;
    }
    if (bytes != null && bytes.isEmpty) bytes = null;
    _artCache[trackId] = bytes;
    _artPending.remove(trackId);
    return bytes;
  }

  /// Миниатюра видео: on_audio_query не умеет; возвращаем null.
  Future<Uint8List?> videoThumbnail(int videoId) async {
    return null;
  }
}