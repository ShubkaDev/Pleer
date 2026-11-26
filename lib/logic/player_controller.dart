import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../services/favorites_store.dart';
import '../services/library_service.dart';
import '../services/permission_service.dart';
import '../services/recorded_media_store.dart';
import '../services/widget_service.dart';

enum RepeatMode { off, all, one }

enum SortMode { title, dateAdded }

class PlayerController extends ChangeNotifier {
  AudioPlayer? _player;
  AudioHandler? _handler;

  final LibraryService library = LibraryService();
  bool _permissionGranted = false;

  // Онбординг (первый запуск)
  bool _onboardingAccepted = false;
  bool get onboardingAccepted => _onboardingAccepted;

  Future<void> loadOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingAccepted = prefs.getBool('onboardingAccepted') ?? false;
  }

  Future<void> acceptOnboarding() async {
    _onboardingAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingAccepted', true);
    notifyListeners();
    // Без этого разрешения (Android 13+) уведомление плеера не появляется вовсе.
    await PermissionService.ensureNotifications();
    // Права уже запрошены явной кнопкой в онбординге; сканируем библиотеку.
    try {
      await refreshLibrary();
    } catch (_) {}
  }

  static PlayerController? ofContextSafe(BuildContext context) {
    try {
      return Provider.of<PlayerController>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  List<Track> _allTracks = [];
  List<Track> get allTracks => _allTracks;

  List<VideoItem> _videos = [];
  List<VideoItem> get videos => _videos;

  List<Track> _recordings = [];
  List<Track> get recordings => _recordings;

  List<Track> _queue = [];
  List<Track> get queue => _queue;
  int _queueIndex = -1;
  int get currentIndexFix => _queueIndex;
  Track? get currentTrack =>
      _queueIndex >= 0 && _queueIndex < _queue.length ? _queue[_queueIndex] : null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  RepeatMode _repeat = RepeatMode.off;
  RepeatMode get repeat => _repeat;

  bool _shuffle = false;
  bool get shuffle => _shuffle;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  SortMode _sortMode = SortMode.title;
  SortMode get sortMode => _sortMode;
  bool _sortAscending = true;
  bool get sortAscending => _sortAscending;

  // Воспроизведение с сохранённой позиции (для подкастов/аудиокниг)
  bool _resumeFromSavedPosition = true;
  bool get resumeFromSavedPosition => _resumeFromSavedPosition;

  // Дополнительные настройки воспроизведения
  int _seekStepSeconds = 10;
  int get seekStepSeconds => _seekStepSeconds;

  bool _autoNext = true;
  bool get autoNext => _autoNext;

  bool _gapless = true;
  bool get gapless => _gapless;

  int _crossfadeMs = 0;
  int get crossfadeMs => _crossfadeMs;

  int _recentPositionSec = 0;
  int get recentPositionSec => _recentPositionSec;

  // Sleep-таймер
  Timer? _sleepTimer;
  DateTime? _sleepEnd; // момент выключения
  bool _fadeBeforeSleep = true;
  bool get sleepTimerActive => _sleepEnd != null;
  Duration get sleepTimeLeft =>
      (_sleepEnd == null)
          ? Duration.zero
          : _sleepEnd!.difference(DateTime.now()).isNegative
              ? Duration.zero
              : _sleepEnd!.difference(DateTime.now());

  // Эквалайзер
  final List<double> _eqGains = [0, 0, 0, 0, 0];
  List<double> get eqGains => List.unmodifiable(_eqGains);
  static const int eqBands = 5;
  static const double eqMin = -15, eqMax = 15;
  String _eqPreset = 'Flat';
  String get eqPreset => _eqPreset;

  bool _eqEnabled = true;
  bool get eqEnabled => _eqEnabled;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  StreamSubscription? _positionSub;
  Duration _position = Duration.zero;
  Duration get position => _position;
  int _lastNotifiedSecond = -1;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _dynamicColor = false;
  bool get dynamicColor => _dynamicColor;

  // Локаль приложения (ru/en/zh)
  Locale _locale = const Locale('ru');
  Locale get locale => _locale;
  static const supportedLocales = [
    Locale('ru'),
    Locale('en'),
    Locale('zh'),
  ];

  // Свойства для скорости
  double get durationMs => currentTrack?.durationMs.toDouble() ?? 0;
  String get currentTitle => currentTrack?.displayTitle ?? '';
  String get currentArtist => currentTrack?.displayArtist ?? '';
  String get currentAlbum => currentTrack?.displayAlbum ?? '';
  int? get currentId => currentTrack?.id;

static const _presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0],
    'Rock': [5, 3, -1, 2, 4],
    'Pop': [-2, 2, 4, 2, -1],
    'Jazz': [4, 2, -1, 2, 4],
    'Classic': [4, 3, 1, -1, -2],
    'Bass boost': [6, 5, 2, 0, 0],
    'Treble': [0, 0, 1, 4, 6],
    'Vocal': [-2, 3, 4, 3, -2],
    'Dance': [6, 3, 0, 3, 5],
    'Hip-Hop': [6, 4, 1, 0, 2],
    'Metal': [4, 2, -2, 3, 5],
    'Acoustic': [4, 3, 2, 1, 2],
    'Podcast': [-1, 2, 5, 3, 1],
    'Loudness': [4, 3, 1, 1, 3],
    'Soft': [-3, -1, 1, 2, 3],
    'Electronic': [5, 3, 0, 2, 6],
  };
  static List<String> get presets => _presets.keys.toList();

  // Кастомные пресеты (имя -> значения полос)
  final Map<String, List<double>> _customPresets = {};

  Future<void> init() async {
    _player = AudioPlayer();
    _player!.playbackEventStream.listen(_onPlaybackEvent);
    // Позицию обновляем раз в секунду: поток отдаёт значения ~5 раз в секунду,
    // и каждый notifyListeners() перестраивал весь список треков вместе с
    // обложками — из-за этого иконки «мигали» во время воспроизведения.
    _player!.positionStream.listen((p) {
      _position = p;
      final second = p.inSeconds;
      if (second != _lastNotifiedSecond) {
        _lastNotifiedSecond = second;
        notifyListeners();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 2];
    _dynamicColor = prefs.getBool('dynamicColor') ?? false;
    final loc = prefs.getString('locale');
    if (loc != null) _locale = Locale(loc);
    _playbackSpeed = prefs.getDouble('speed') ?? 1.0;
    _eqPreset = prefs.getString('eqPreset') ?? 'Flat';
    _eqEnabled = prefs.getBool('eqEnabled') ?? true;
    if (_eqPreset == 'Bass boost') {
      // усиление басов отдельным флагом не храним — просто пресет
    }
    _eqGains
      ..clear()
      ..addAll(_presets[_eqPreset] ?? _presets['Flat']!);
    _loadCustomPresets();
    _shuffle = prefs.getBool('shuffle') ?? false;
    _normalize = prefs.getBool('normalize') ?? false;
    _resumeFromSavedPosition = prefs.getBool('resumeFromSavedPosition') ?? true;
    _sortMode = SortMode.values[prefs.getInt('sortMode') ?? 0];
    _sortAscending = prefs.getBool('sortAscending') ?? true;
    _seekStepSeconds = prefs.getInt('seekStep') ?? 10;
    _autoNext = prefs.getBool('autoNext') ?? true;
    _gapless = prefs.getBool('gapless') ?? true;
    _crossfadeMs = prefs.getInt('crossfade') ?? 0;
    _applyNormalize();

    _player!.setSpeed(_playbackSpeed);

    // Регистрируем фоновый сервис
    await _initAudioService();

    // ВАЖНО: не запрашиваем права и не сканируем здесь.
    // Сканирование выполняется после согласия в онбординге (acceptOnboarding).
    notifyListeners();
  }

  Future<void> _initAudioService() async {
    try {
      // Таймаут обязателен: привязка к сервису после перезагрузки устройства
      // иногда не завершается, и запуск приложения зависал до runApp.
      _handler = await AudioService.init(
        builder: () => _PlayerAudioHandler(_player!, this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.multitool.audio.channel',
          androidNotificationChannelName: 'Воспроизведение',
          androidNotificationIcon: 'drawable/ic_stat_pleer',
          androidNotificationOngoing: false,
          // false: сервис остаётся в foreground и на паузе — иначе уведомление
          // гаснет и воспроизведение больше не возобновляется.
          androidStopForegroundOnPause: false,
          androidResumeOnClick: true,
          androidNotificationClickStartsActivity: true,
        ),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // сервис может быть недоступен на Windows/desktop — работаем без него
      debugPrint('PLEER/audioService: init failed: $e');
      _handler = null;
    }
  }

  /// Гарантирует наличие фонового сервиса: после «Стоп» из уведомления
  /// audio_service мог быть отвязан, и без повторной инициализации плеер
  /// больше не показывал ни уведомление, ни элементы управления.
  Future<void> _ensureHandler() async {
    if (_handler != null || !Platform.isAndroid) return;
    await _initAudioService();
  }

  /// Обложка трека во временном файле (или null, если обложки нет —
  /// тогда в уведомлении остаётся иконка приложения).
  Future<Uri?> _artUriFor(Track t) async {
    try {
      final bytes = await library.albumArt(t.id);
      if (bytes == null || bytes.isEmpty) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pleer_art_${t.id}.jpg');
      if (!file.existsSync() || file.lengthSync() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  /// Публикует текущий трек в фоновый медиа-сервис (уведомление / лок-скрин):
  /// название, исполнитель, альбом и обложка (если её нет — иконка приложения).
  Future<void> _publishMediaItem({bool withArtwork = true}) async {
    final h = _handler;
    final t = currentTrack;
    if (h == null || t == null) return;
    final art = withArtwork ? await _artUriFor(t) : _lastArtUri;
    _lastArtUri = art;
    final artist = t.artist.trim().isNotEmpty
        ? t.artist.trim()
        : (t.album.trim().isNotEmpty ? t.album.trim() : 'Pleer');
    // Пустой заголовок Android показывает как название приложения,
    // поэтому всегда подставляем осмысленный текст.
    final title = t.displayTitle.trim().isNotEmpty
        ? t.displayTitle.trim()
        : 'Без названия';
    try {
      await h.updateMediaItem(MediaItem(
        id: 'pleer_${t.id}',
        title: title,
        artist: artist,
        album: t.album,
        duration: t.durationMs > 0 ? Duration(milliseconds: t.durationMs) : null,
        artUri: art,
      ));
    } catch (e) {
      debugPrint('PLEER/notification: publish failed: $e');
    }
  }

  Uri? _lastArtUri;

  /// Повторная публикация текущего трека. Вызывается из аудио-хендлера, когда
  /// Android-сервис поднялся позже, чем трек был отправлен в уведомление.
  Future<void> ensureMediaPublished() => _publishMediaItem();

  Future<void> refreshLibrary() async {
    if (!_permissionGranted) {
      _permissionGranted = await library.ensurePermission();
    }
    if (!_permissionGranted) {
      if (Platform.isAndroid) {
        // на десктопе медиасторов нет, работаем без прав
      }
    }
    library.clearArtCache();
    try {
      _allTracks = await library.scanTracks();
    } catch (_) {
      _allTracks = [];
    }
    notifyListeners();
  }

  /// Сканирует видеотеку через MediaStore и добавляет записи экрана,
  /// сделанные в приложении (они видны даже без доступа к медиатеке).
  Future<void> refreshVideos() async {
    if (!_permissionGranted) {
      _permissionGranted = await library.ensurePermission();
    }
    List<VideoItem> scanned = [];
    try {
      scanned = await library.scanVideos();
    } catch (_) {
      scanned = [];
    }

    final own = <VideoItem>[];
    try {
      for (final item in await RecordedMediaStore.load()) {
        final uri = (item['uri'] as String?) ?? '';
        if (uri.isEmpty) continue;
        if (scanned.any((v) => v.data == uri)) continue;
        final ts = (item['ts'] as num?)?.toInt() ?? 0;
        own.add(VideoItem(
          id: uri.hashCode,
          data: uri,
          title: (item['title'] as String?) ?? 'Запись экрана',
          album: 'Pleer',
          artist: '',
          durationMs: 0,
          size: 0,
          dateAdded: ts ~/ 1000,
        ));
      }
    } catch (_) {}

    _videos = [...own, ...scanned];
    notifyListeners();
  }

  /// Аудиозаписи, сделанные в самом приложении (<документы>/recordings).
  Future<void> refreshRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordsDir = Directory('${dir.path}/recordings');
      if (!recordsDir.existsSync()) {
        _recordings = [];
        notifyListeners();
        return;
      }
      const audioExts = ['.m4a', '.mp3', '.wav', '.aac', '.ogg', '.opus', '.flac'];
      final files = recordsDir
          .listSync()
          .whereType<File>()
          .where((f) => audioExts.any(f.path.toLowerCase().endsWith))
          .toList()
        ..sort((a, b) {
          try {
            return b.statSync().modified.compareTo(a.statSync().modified);
          } catch (_) {
            return 0;
          }
        });
      _recordings = files.map((f) {
        int ms = 0;
        try {
          final stat = f.statSync();
          ms = stat.modified.millisecondsSinceEpoch;
        } catch (_) {}
        return Track(
          id: f.path.hashCode,
          data: f.path,
          title: _recordingTitle(f.path, ms),
          artist: 'Моя запись',
          album: 'Pleer',
          durationMs: 0,
          dateAdded: ms ~/ 1000,
        );
      }).toList();
    } catch (_) {
      _recordings = [];
    }
    notifyListeners();
  }

  String _recordingTitle(String path, int fallbackMs) {
    final name = path.split(Platform.pathSeparator).last;
    final match = RegExp(r'rec_(\d+)').firstMatch(name);
    final ms = match != null
        ? int.tryParse(match.group(1) ?? '') ?? fallbackMs
        : fallbackMs;
    if (ms <= 0) return name;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Запись ${two(d.day)}.${two(d.month)}.${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  /// Удаляет файл записи и обновляет список.
  Future<void> deleteRecording(Track track) async {
    try {
      final f = File(track.data);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    await refreshRecordings();
  }

  // ---- Мелодия звонка (Android) ----
  static const MethodChannel _ringtoneChannel = MethodChannel('multitool.ringtone');

  /// Можно ли записать в системные настройки (нужно для мелодии звонка).
  Future<bool> canWriteSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ringtoneChannel.invokeMethod<bool>('isWritable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Открывает экран «Доступ к изменению системных настроек».
  Future<void> requestWriteSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ringtoneChannel.invokeMethod('requestWriteSettings');
    } catch (_) {}
  }

  /// Устанавливает трек как мелодию звонка. Возвращает true при успехе.
  Future<bool> setAsRingtone(Track track) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ringtoneChannel.invokeMethod<bool>('setRingtone', {
        'uri': track.data,
      }) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---- Переименование / удаление файлов (Android) ----
  static const MethodChannel _mediaChannel = MethodChannel('multitool.media');

  /// Переименовывает медиафайл. Возвращает true при успехе.
  Future<bool> renameMedia(Track track, String newName) async {
    if (!Platform.isAndroid) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    try {
      final ok = await _mediaChannel.invokeMethod<bool>('rename', {
        'uri': track.data,
        'newName': trimmed,
      }) ?? false;
      if (ok) await refreshLibrary();
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Удаляет медиафайл. Возвращает true при успехе.
  Future<bool> deleteMedia(Track track) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _mediaChannel.invokeMethod<bool>('delete', {
        'uri': track.data,
      }) ?? false;
      if (ok) {
        // Если удаляем текущий трек — останавливаем плеер.
        if (currentTrack?.id == track.id) stop();
        await refreshLibrary();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  void onPausedByHeadset() {
    pause();
  }

  void playTracks(List<Track> tracks, {int startIndex = 0}) {
    if (tracks.isEmpty) return;
    _queue = List.of(tracks);
    if (_shuffle) _queue.shuffle();
    _queueIndex = _findIndex(startIndex);
    _playIndex(_queueIndex);
  }

  int _findIndex(int originalIndex) {
    // Когда очередь перетасована, ищем тот же трек по id.
    final orig = _queue.length > originalIndex ? _queue[originalIndex].id : -1;
    final idx = _queue.indexWhere((t) => t.id == orig);
    return idx >= 0 ? idx : (originalIndex.clamp(0, _queue.length - 1));
  }

  void playTrack(Track track) {
    final queue = _queue.isNotEmpty ? _queue : [track];
    final idx = queue.indexWhere((t) => t.id == track.id);
    _queue = queue;
    _queueIndex = idx >= 0 ? idx : 0;
    _playIndex(_queueIndex);
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queueIndex = index;
    final track = _queue[index];
    _isLoading = true;
    notifyListeners();
    // Публикуем трек ДО старта: уведомление сразу показывает верное название
    // и обложку, а не предыдущую песню.
    await _ensureHandler();
    await _publishMediaItem();
    try {
      final srcUri = _mediaUri(track.data);
      await _player!.setAudioSource(
        AudioSource.uri(
          srcUri,
          tag: track,
        ),
      );
      await _player!.setSpeed(_playbackSpeed);

      // История воспроизведения
      await HistoryStore.instance.pushRecent(track.id);

      // Воспроизводим с сохранённой позиции (если был перерыв > 5 мин и это не совсем начало)
      if (_resumeFromSavedPosition) {
        final saved = HistoryStore.instance.positionOf(track.id);
        final trackLen = track.durationMs ~/ 1000;
        if (saved > 3 && trackLen > 0 && (saved / trackLen) < 0.95) {
          await _player!.seek(Duration(seconds: saved));
        }
      }

      await _player!.play();
      _isPlaying = true;
    } catch (e, st) {
      // Файл недоступен/битый — пишем в лог, чтобы было видно причину.
      debugPrint('PLEER/play: error for "${track.data}": $e\n$st');
      _isPlaying = false;
    } finally {
      _isLoading = false;
      notifyListeners();
      _syncWidget();
    }
  }

  /// Воспроизводит файл, открытый из проводника/другого приложения.
  /// [uri] может быть content:// или file://.
  Future<void> playExternal(Uri uri, {String title = ''}) async {
    final t = Track(
      id: uri.toString().hashCode,
      data: uri.toString(),
      title: title.isNotEmpty ? title : (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Файл'),
      artist: '',
      album: '',
      durationMs: 0,
      dateAdded: 0,
    );
    _queue = [t];
    _queueIndex = 0;
    await _playIndex(0);
  }

  /// Преобразует строку пути в корректный Uri (content:// или файл).
  static Uri _mediaUri(String data) {
    if (data.startsWith('content://') || data.startsWith('file://')) {
      return Uri.parse(data);
    }
    return Uri.file(data);
  }

  Future<void> togglePlay() async {
    final p = _player;
    if (p == null) return;
    // Ориентируемся на РЕАЛЬНОЕ состояние плеера, а не на флаг _isPlaying,
    // иначе после «Стоп» нажатие снова ставит паузу вместо запуска.
    if (p.playing) {
      await pause();
    } else {
      await _resumeOrReload();
    }
  }

  AudioPlayer? get _currentPlayer => _player;

  bool _notificationsAsked = false;

  /// Один раз за сессию доспрашиваем разрешение на уведомления — без него
  /// сервис воспроизведения не покажет уведомление и лок-скрин на Android 13+.
  Future<void> _ensureNotificationsOnce() async {
    if (_notificationsAsked) return;
    _notificationsAsked = true;
    await PermissionService.ensureNotifications();
  }

  Future<void> play() async {
    await _ensureNotificationsOnce();
    // Сервис мог быть отвязан системой или кнопкой «Стоп» — поднимаем заново.
    await _ensureHandler();
    // Не блокируемся флагом: он мог устареть (например после «Стоп»).
    if (_player?.playing == true) return;
    await _publishMediaItem();
    await _resumeOrReload();
  }

  /// Возобновляет паузу; если плеер был остановлен (нет активного источника),
  /// перезагружает текущий трек и запускает с сохранённой позиции.
  Future<void> _resumeOrReload() async {
    if (_queueIndex < 0 || _queueIndex >= _queue.length) return;
    final p = _player;
    if (p == null) return;
    // Если источник жив (не idle/completed и не пустой) — просто продолжаем.
    try {
      final hasSource = p.audioSource != null;
      if (hasSource &&
          p.processingState != ProcessingState.idle &&
          p.processingState != ProcessingState.completed) {
        await p.play();
        _isPlaying = true;
        notifyListeners();
        _syncWidget();
        return;
      }
    } catch (_) {}
    // Иначе надёжно перезагружаем трек с нуля.
    debugPrint('PLEER/play: reload track #$_queueIndex');
    await _playIndex(_queueIndex);
  }

  Future<void> pause() async {
    await _saveCurrentPosition();
    try {
      await _player?.pause();
    } catch (_) {}
    _isPlaying = false;
    notifyListeners();
    _syncWidget();
  }

  Future<void> stop() async {
    // Не вызываем just_audio.stop(): он переводит плеер в idle и теряет
    // источник, после чего воспроизведение уже не запускалось.
    // Ставим паузу, возвращаем позицию в начало и оставляем сервис живым,
    // чтобы кнопка play работала и уведомление не пропадало.
    await _saveCurrentPosition();
    try {
      await _player?.pause();
      await _player?.seek(Duration.zero);
    } catch (_) {}
    _isPlaying = false;
    _position = Duration.zero;
    _lastNotifiedSecond = -1;
    notifyListeners();
    _syncWidget();
    await _publishMediaItem(withArtwork: false);
  }

  /// Сообщает сервису уведомлений, что воспроизведение остановлено.
  /// Отдельного состояния не отправляем: pause() и seek() в just_audio сами
  /// вызывают playbackEvent, по которому обработчик обновляет уведомление
  /// (processingState остаётся ready, поэтому сервис не гаснет).
  Future<void> publishStoppedState() async {
    // Намеренно пусто: состояние уведомления обновляется из playbackEventStream.
  }

  Future<void> _saveCurrentPosition() async {
    final t = currentTrack;
    if (t != null && _position.inSeconds > 0) {
      await HistoryStore.instance.savePosition(t.id, _position.inSeconds);
    }
  }

  void next({bool manual = true}) {
    if (_queue.isEmpty) return;
    if (_repeat == RepeatMode.one && !manual) return; // повтор одного
    int idx = _queueIndex + 1;
    if (idx >= _queue.length) {
      if (_repeat == RepeatMode.all || _repeat == RepeatMode.one) {
        idx = 0;
      } else {
        idx = _queue.length - 1;
        _playIndex(idx);
        return;
      }
    }
    _playIndex(idx);
  }

  void previous() {
    if (_queue.isEmpty) return;
    // если играет >3 сек — рестарт
    if (_position.inSeconds > 3) {
      _player!.seek(Duration.zero);
      return;
    }
    int idx = _queueIndex - 1;
    if (idx < 0) idx = 0;
    _playIndex(idx);
  }

  void seek(Duration to) {
    _player?.seek(to);
  }

  // ---- Управление очередью ----
  void jumpToQueueIndex(int i) {
    if (i < 0 || i >= _queue.length) return;
    _playIndex(i);
  }

  void removeFromQueue(int i) {
    if (i < 0 || i >= _queue.length) return;
    _queue.removeAt(i);
    if (i < _queueIndex) {
      _queueIndex--;
    } else if (i == _queueIndex) {
      if (_queue.isNotEmpty) {
        final idx = i < _queue.length ? i : _queue.length - 1;
        _queueIndex = idx;
        _playIndex(idx);
      } else {
        _queueIndex = -1;
        _player?.stop();
      }
    }
    notifyListeners();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = _queue.removeAt(oldIndex);
    final target = newIndex < 0 ? 0 : (newIndex > _queue.length ? _queue.length : newIndex);
    _queue.insert(target, item);
    if (_queueIndex == oldIndex) {
      _queueIndex = target;
    } else if (oldIndex < _queueIndex && target >= _queueIndex) {
      _queueIndex--;
    } else if (oldIndex > _queueIndex && target <= _queueIndex) {
      _queueIndex++;
    }
    notifyListeners();
  }

  void setRepeat(RepeatMode mode) {
    _repeat = mode;
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _saveBool('shuffle', _shuffle);
    if (_shuffle && _queue.isNotEmpty) {
      final current = currentId;
      _queue.shuffle();
      final idx = _queue.indexWhere((t) => t.id == current);
      if (idx >= 0) _queueIndex = idx;
    }
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _player?.setSpeed(speed);
    _saveDouble('speed', speed);
    notifyListeners();
  }

  void setResumeFromSavedPosition(bool value) {
    _resumeFromSavedPosition = value;
    _saveBool('resumeFromSavedPosition', value);
    notifyListeners();
  }

  // Расширенные настройки воспроизведения
  void setSeekStep(int seconds) {
    _seekStepSeconds = seconds;
    _saveInt('seekStep', seconds);
    notifyListeners();
  }

  void setAutoNext(bool value) {
    _autoNext = value;
    _saveBool('autoNext', value);
    notifyListeners();
    // если выключен автопереход и доиграл — стоп
  }

  void setGapless(bool value) {
    _gapless = value;
    _saveBool('gapless', value);
    notifyListeners();
  }

  void setCrossfade(int ms) {
    _crossfadeMs = ms;
    _saveInt('crossfade', ms);
    notifyListeners();
  }

  void setRecentPosition(int seconds) {
    _recentPositionSec = seconds;
    notifyListeners();
  }

  // Сортировка
  void setSortMode(SortMode mode) {
    _sortMode = mode;
    _saveInt('sortMode', mode.index);
    notifyListeners();
  }

  void setSortAscending(bool asc) {
    _sortAscending = asc;
    _saveBool('sortAscending', asc);
    notifyListeners();
  }

  /// Возвращает треки библиотеки в выбранном порядке:
  /// по названию или по дате добавления.
  List<Track> sortTracks(List<Track> input) {
    final list = List.of(input);
    switch (_sortMode) {
      case SortMode.dateAdded:
        list.sort((a, b) =>
            _sortAscending ? a.dateAdded - b.dateAdded : b.dateAdded - a.dateAdded);
        break;
      case SortMode.title:
        list.sort((a, b) {
          final r = a.displayTitle
              .toLowerCase()
              .compareTo(b.displayTitle.toLowerCase());
          return _sortAscending ? r : -r;
        });
    }
    return list;
  }

  // ---- Нормализация звука ----
  bool _normalize = false;
  bool get normalize => _normalize;

  void setNormalize(bool value) {
    _normalize = value;
    _applyNormalize();
    _saveBool('normalize', value);
    notifyListeners();
  }

  void _applyNormalize() {
    // Нормализация через target-громкость just_audio + пресет Loudness для
    // компенсации разницы треков. Реальная RMS-нормализация требует анализа
    // файла; здесь применяем громкость по умолчанию и пересчёт с пресетом,
    // чтобы полосы эквалайзера не сбивали баланс.
    _player?.setVolume(_normalize ? _normalizedVolume() : _enabledVolume());
  }

  double _normalizedVolume() {
    // Лёгкое усиление слабых треков + компенсация громкости эквалайзера.
    final base = 1.0;
    final eqComp = _eqEnabled ? (0.8 + _avgPositiveGain() * 0.015) : 1.0;
    return (base * eqComp).clamp(0.0, 1.0);
  }

  // ---- Эквалайзер (всего 5 полос на Andoid; на Windows графический EQ недоступен
  // в just_audio, поэтому только пресеты-баланс для полосы через громкость) ----
  // Реальный 10-полосный EQ на Android можно включить через Android AudioEffects,
  // за пределами just_audio. Здесь реализуем 5-полосный диапазон-пресет + bass/treble.

  void setEqBand(int band, double gain) {
    if (band < 0 || band >= eqBands) return;
    _eqGains[band] = gain.clamp(eqMin, eqMax);
    _eqPreset = 'Custom';
    _applyEq();
    _saveString('eqPreset', _eqPreset);
    notifyListeners();
  }

  void applyEqPreset(String name) {
    _eqPreset = _presets.containsKey(name) ? name : 'Flat';
    _eqGains
      ..clear()
      ..addAll(_presets[_eqPreset]!);
    _applyEq();
    _saveString('eqPreset', _eqPreset);
    notifyListeners();
  }

  void setEqEnabled(bool enabled) {
    _eqEnabled = enabled;
    _saveBool('eqEnabled', enabled);
    _applyEq();
    notifyListeners();
  }

  // Кастомные пресеты эквалайзера
  List<String> get customPresetNames => _customPresets.keys.toList();

  void saveCustomPreset(String name, List<double> gains) {
    _customPresets[name] = List.of(gains);
    _saveCustomPresets();
    notifyListeners();
  }

  void deleteCustomPreset(String name) {
    _customPresets.remove(name);
    _saveCustomPresets();
    notifyListeners();
  }

  void applyCustomPreset(String name) {
    final g = _customPresets[name];
    if (g == null) return;
    _eqGains
      ..clear()
      ..addAll(g);
    _eqPreset = name;
    _applyEq();
    _saveString('eqPreset', _eqPreset);
    notifyListeners();
  }

  Future<void> _saveCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _customPresets.entries
        .map((e) => '${e.key}:${e.value.join(',')}')
        .join(';');
    await prefs.setString('customPresets', encoded);
  }

  void _loadCustomPresets() {
    // загрузка выполняется асинхронно при инициализации
    _loadCustomPresetsAsync();
  }

  Future<void> _loadCustomPresetsAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('customPresets');
    if (raw == null || raw.isEmpty) return;
    for (final entry in raw.split(';')) {
      final idx = entry.indexOf(':');
      if (idx <= 0) continue;
      final name = entry.substring(0, idx);
      final values = entry
          .substring(idx + 1)
          .split(',')
          .where((e) => e.isNotEmpty)
          .map(double.parse)
          .toList();
      _customPresets[name] = values;
    }
    notifyListeners();
  }

  void _applyEq() {
    // Применяем коррекцию через громкость-веса: на Android можно было бы
    // использовать native AudioEffect. В this реализации мы храним
    // значения и передаем в нативный канал (см. MainActivity / equalizerHelper).
    _player?.setVolume(_enabledVolume());
    // Заглушка эквалайзера: полноценный контур — нативный плагин,
    // добавлен в android/... (equalizerHelper). Здесь отметка для UI.
  }

  double _enabledVolume() {
    final v = 1.0 * (0.75 + _avgPositiveGain() * 0.02);
    return _eqEnabled ? v.clamp(0.0, 1.0) : 1.0;
  }

  double _avgPositiveGain() {
    double s = 0;
    for (final g in _eqGains) {
      if (g > 0) s += g;
    }
    return s / _eqGains.length;
  }

  // ---- Sleep-таймер ----
  void startSleepTimer(Duration duration, {bool fade = true}) {
    _fadeBeforeSleep = fade;
    _sleepTimer?.cancel();
    _sleepEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () async {
      if (_fadeBeforeSleep && _isPlaying) {
        final fadeDuration = const Duration(seconds: 8);
        final step = 40;
        final stepDur = fadeDuration.inMilliseconds ~/ step;
        for (int i = 1; i <= step; i++) {
          await Future.delayed(Duration(milliseconds: stepDur));
          _player?.setVolume(1.0 - (i / step));
        }
        _player?.setVolume(1.0);
      }
      await pause();
      _sleepEnd = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepEnd = null;
    notifyListeners();
  }

  // ---- Тема ----
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveInt('themeMode', mode.index);
    notifyListeners();
  }

  void setDynamicColor(bool value) {
    _dynamicColor = value;
    _saveBool('dynamicColor', value);
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    _saveString('locale', locale.languageCode);
    notifyListeners();
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    final completed = event.processingState == ProcessingState.completed;

    // Трек завершился: считаем, что не играем, иначе togglePlay() будет
    // пытаться поставить паузу вместо запуска.
    if (completed) {
      _isPlaying = false;
      if (_autoNext && _queueIndex < _queue.length - 1) {
        // Автопереход к следующему треку.
        _playIndex(_queueIndex + 1);
      }
      notifyListeners();
      _syncWidget();
      return;
    }

    _isPlaying = _player!.playing;
    notifyListeners();
    _syncWidget();
  }

  /// Обновляет данные виджета на главном экране (Android).
  void _syncWidget() {
    WidgetService.update(
      title: currentTitle,
      artist: currentArtist,
      isPlaying: _isPlaying,
    );
  }

  Future<void> _saveBool(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, v);
  }

  Future<void> _saveDouble(String k, double v) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(k, v);
  }

  Future<void> _saveString(String k, String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(k, v);
  }

  Future<void> _saveInt(String k, int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(k, v);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player?.dispose();
    _positionSub?.cancel();
    super.dispose();
  }
}

/// Фоновый аудиохендлер для уведомления и элементов управления.
class _PlayerAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  final PlayerController _ctrl;
  _PlayerAudioHandler(this._player, this._ctrl) {
    _player.playbackEventStream.listen((e) {
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        playing: _player.playing,
        processingState: _mapState(e.processingState),
        updatePosition: _player.position,
      ));
      // Android рисует название/обложку только если в сервис пришёл MediaItem.
      // Если он потерялся (сервис поднялся позже трека) — досылаем.
      if (mediaItem.value == null && _ctrl.currentTrack != null) {
        _ctrl.ensureMediaPublished();
      }
    });
    _player.positionStream.listen((p) {
      playbackState.add(playbackState.value.copyWith(updatePosition: p));
    });
  }

  /// Корректный маппинг состояния just_audio -> audio_service.
  /// ВАЖНО: paused должен оставаться ready, иначе audio_service считает
  /// сервис остановленным, гасит уведомление и воспроизведение не возобновляется.
  AudioProcessingState _mapState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
    }
  }

  @override
  Future<void> play() async {
    await _ctrl.play();
  }

  @override
  Future<void> pause() async {
    await _ctrl.pause();
  }

  @override
  Future<void> stop() async {
    // Не отдаём сервису состояние idle: иначе уведомление гаснет, а после
    // «Стоп» воспроизведение больше не запускается. Останавливаем звук
    // и оставляем уведомление с рабочей кнопкой play.
    await _ctrl.stop();
    await _ctrl.publishStoppedState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    _ctrl.next();
  }

  @override
  Future<void> skipToPrevious() async {
    _ctrl.previous();
  }

  @override
  Future<void> fastForward() async {
    await _player.seek(_player.position + Duration(seconds: 10));
  }

  @override
  Future<void> rewind() async {
    final target = _player.position - const Duration(seconds: 10);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }
}
