import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../services/recorder_controller.dart';
import '../theme/design.dart';
import 'widgets/glass_card.dart';

class AudioRecorderScreen extends StatelessWidget {
  const AudioRecorderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AudioRecorderController(),
      child: const _AudioRecorderBody(),
    );
  }
}

class _AudioRecorderBody extends StatefulWidget {
  const _AudioRecorderBody();

  @override
  State<_AudioRecorderBody> createState() => _AudioRecorderBodyState();
}

class _AudioRecorderBodyState extends State<_AudioRecorderBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final AudioPlayer _player = AudioPlayer();

  List<File> _files = [];
  bool _loadingFiles = true;
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _loadFiles();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/recordings');
      if (!d.existsSync()) {
        if (mounted) setState(() { _files = []; _loadingFiles = false; });
        return;
      }
      final files = d
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.m4a'))
          .toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
      if (!mounted) return;
      setState(() { _files = files; _loadingFiles = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleRecord(AudioRecorderController ctrl) async {
    if (ctrl.isRecording) {
      await ctrl.stop();
      await _loadFiles();
      _snack('Запись сохранена');
    } else {
      try {
        await ctrl.start();
      } catch (e) {
        _snack('$e');
      }
    }
  }

  Future<void> _play(File f) async {
    try {
      if (_playingPath == f.path && _player.playing) {
        await _player.pause();
        setState(() => _playingPath = null);
        return;
      }
      await _player.setFilePath(f.path);
      _player.play();
      setState(() => _playingPath = f.path);
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingPath = null);
        }
      });
    } catch (e) {
      _snack('Не удалось воспроизвести: $e');
    }
  }

  Future<void> _delete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(f.uri.pathSegments.last),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await f.delete();
      } catch (_) {}
      await _loadFiles();
      _snack('Запись удалена');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AudioRecorderController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Запись звука'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0B14), Color(0xFF151033), Color(0xFF2A0F3D)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _recorderVisual(ctrl),
            const SizedBox(height: 20),
            Text('Мои записи',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(child: _filesList(ctrl)),
          ],
        ),
      ),
    );
  }

  Widget _recorderVisual(AudioRecorderController ctrl) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final scale = ctrl.isRecording ? 1.0 + _pulse.value * 0.12 : 1.0;
            final glow = ctrl.isRecording ? (0.35 + _pulse.value * 0.35) : 0.25;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ctrl.isRecording
                      ? const LinearGradient(
                          colors: [Color(0xFFFF3B3B), Color(0xFFE439B3)],
                        )
                      : PleerDesign.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (ctrl.isRecording
                              ? const Color(0xFFFF3B3B)
                              : const Color(0xFFA62AFF))
                          .withValues(alpha: glow),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: ctrl.isRecording
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.circle,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 8),
                            Text(_fmt(ctrl.duration),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                          ],
                        )
                      : const Icon(Icons.mic, color: Colors.white, size: 56),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _toggleRecord(ctrl),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                ctrl.isRecording ? const Color(0xFFFF3B3B) : Colors.white,
            foregroundColor:
                ctrl.isRecording ? Colors.white : const Color(0xFF5716FF),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          icon: Icon(ctrl.isRecording ? Icons.stop : Icons.mic),
          label: Text(
            ctrl.isRecording ? 'Остановить' : 'Начать запись',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _filesList(AudioRecorderController ctrl) {
    if (_loadingFiles) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_files.isEmpty) {
      return Center(
        child: Text('Пока нет записей',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _files.length,
      itemBuilder: (context, i) {
        final f = _files[i];
        final name = f.uri.pathSegments.last;
        final size = (f.lengthSync() / 1024).toStringAsFixed(0);
        final playing = _playingPath == f.path;
        return GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              child: Icon(playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white),
            ),
            title: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('$size КБ',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              onPressed: () => _delete(f),
            ),
            onTap: () => _play(f),
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}