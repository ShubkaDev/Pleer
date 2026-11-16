import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'permission_service.dart';

/// Запись звука с микрофона (Android + Windows). Максимально устойчива:
/// любые ошибки превращаются в понятное исключение, состояние не «зависает».
class AudioRecorderController extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String _currentPath = '';
  String get currentPath => _currentPath;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;
  Timer? _timer;

  /// Проверяет/запрашивает доступ к микрофону (через permission_handler).
  Future<bool> ensurePermission() async {
    return PermissionService.ensureMicrophone();
  }

  Future<void> start() async {
    if (_isRecording) return;

    final granted = await ensurePermission();
    if (!granted) {
      throw StateError('Нет доступа к микрофону');
    }

    String path;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordsDir = Directory('${dir.path}/recordings');
      if (!recordsDir.existsSync()) recordsDir.createSync(recursive: true);
      path = '${recordsDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } catch (e) {
      throw StateError('Не удалось создать файл записи: $e');
    }

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (e) {
      _isRecording = false;
      throw StateError('Не удалось начать запись: $e');
    }

    _currentPath = path;
    _isRecording = true;
    _duration = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _duration += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<String?> stop() async {
    _timer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    _isRecording = false;
    _currentPath = path ?? _currentPath;
    notifyListeners();
    return _currentPath;
  }

  Future<void> pause() async {
    try {
      await _recorder.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _recorder.resume();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _recorder.dispose();
    } catch (_) {}
    super.dispose();
  }
}