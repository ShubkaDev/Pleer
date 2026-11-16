import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/models.dart';

const MethodChannel _pipChannel = MethodChannel('multitool.pip');

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.video,
    required this.playlist,
  });

  final VideoItem video;
  final List<VideoItem> playlist;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;
  bool _unsupported = false;
  bool _piPEnabled = false;
  double _videoSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    final supported = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    if (!supported) {
      _unsupported = true;
      return;
    }
    final data = widget.video.data;
    final options = VideoPlayerOptions(
      allowBackgroundPlayback: false,
      mixWithOthers: false,
    );
    if (data.startsWith('content://')) {
      _videoController = VideoPlayerController.contentUri(
        Uri.parse(data),
        videoPlayerOptions: options,
      );
    } else if (data.startsWith('file://')) {
      _videoController = VideoPlayerController.file(
        File(Uri.parse(data).toFilePath()),
        videoPlayerOptions: options,
      );
    } else {
      _videoController = VideoPlayerController.file(
        File(data),
        videoPlayerOptions: options,
      );
    }
    _init();
    _initPip();
  }

  Future<void> _initPip() async {
    if (!Platform.isAndroid) return;
    try {
      final supported = await _pipChannel.invokeMethod<bool>('isSupported');
      if (supported != true) return;
      await _pipChannel.invokeMethod('setEnabled', true);
      if (mounted) setState(() => _piPEnabled = true);
    } catch (_) {}
  }

  Future<void> _init() async {
    final ctrl = _videoController;
    if (ctrl == null) return;
    try {
      await ctrl.initialize();
    } catch (_) {
      if (mounted) setState(() => _unsupported = true);
      return;
    }
    final chewie = ChewieController(
      videoPlayerController: ctrl,
      autoPlay: true,
      looping: false,
      allowedScreenSleep: false,
      fullScreenByDefault: false,
      placeholder: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorBuilder: (ctx, msg) => Center(
        child: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
    if (!mounted) return;
    setState(() {
      _chewieController = chewie;
      _initialized = true;
    });
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _pipChannel.invokeMethod('setEnabled', false).catchError((_) {});
    }
    _chewieController?.dispose();
    _videoController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unsupported) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.video.displayTitle,
              style: const TextStyle(fontSize: 16)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text(
                  'Воспроизведение видео на этой платформе\nпока не поддерживается.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.video.displayTitle,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          // Скорость видео (не сохраняется между запусками)
          TextButton(
            onPressed: _pickVideoSpeed,
            child: Text(
              '${_videoSpeed == _videoSpeed.roundToDouble() ? _videoSpeed.toStringAsFixed(0) : _videoSpeed.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // ПиП
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt),
            tooltip: 'Картинка-в-картинке',
            onPressed: _togglePiP,
          ),
          // Автоповорот
          IconButton(
            icon: const Icon(Icons.screen_rotation),
            tooltip: 'Автоповорот',
            onPressed: _toggleAutoRotate,
          ),
        ],
      ),
      body: Center(
        child: (_initialized &&
                _chewieController != null &&
                _videoController != null)
            ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: _initialized
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {},
                  ),
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {},
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Future<void> _togglePiP() async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1200),
          content: Text('Картинка-в-картинке доступна на Android'),
        ),
      );
      return;
    }
    try {
      final supported = await _pipChannel.invokeMethod<bool>('isSupported');
      if (supported != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1200),
            content: Text('Устройство не поддерживает PiP'),
          ),
        );
        return;
      }
      await _pipChannel.invokeMethod('setEnabled', true);
      await _pipChannel.invokeMethod<bool>('enter');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1200),
          content: Text('Не удалось включить PiP'),
        ),
      );
    }
  }

  void _toggleAutoRotate() {
    // На Android вращение экрана по датчику. Здесь используется
    // SystemChrome.setPreferredOrientations в сервисе подключения.
    // Для простоты: показать состояние.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 900),
        content: Text('Автоповорот: переключается системно'),
      ),
    );
  }

  /// Выбор скорости видео (применяется только к текущему просмотру и
  /// НЕ сохраняется — каждый раз по умолчанию 1x).
  Future<void> _pickVideoSpeed() async {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final vc = _videoController;
    final choice = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in speeds)
              ListTile(
                leading: Icon(
                  s == _videoSpeed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: Colors.white,
                ),
                title: Text(
                  '${s == s.roundToDouble() ? s.toStringAsFixed(1) : s.toStringAsFixed(2)}x',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted || vc == null) return;
    setState(() => _videoSpeed = choice);
    try {
      await vc.setPlaybackSpeed(choice);
    } catch (_) {}
  }
}