
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/player_controller.dart';
import '../theme/design.dart';
import 'equalizer_screen.dart';
import 'queue_screen.dart';
import 'widgets/track_art.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final track = ctrl.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: PleerDesign.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Ничего не играет', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
                // Верхняя панель
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.queue_music, color: Colors.white),
                      tooltip: 'Очередь',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QueueScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      tooltip: 'Эквалайзер',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _BigArtwork(id: ctrl.currentId),
                const SizedBox(height: 30),
                Text(
                  ctrl.currentTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ctrl.currentArtist,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                _Progress(ctrl: ctrl),
                const SizedBox(height: 6),
                _Controls(ctrl: ctrl),
                const SizedBox(height: 18),
                _SeekRow(ctrl: ctrl),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
    );
  }
}

class _BigArtwork extends StatelessWidget {
  const _BigArtwork({required this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.72;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: PleerDesign.brLg,
        gradient: PleerDesign.brandGradient,
        boxShadow: PleerDesign.glow(const Color(0xFF7B45FF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: id == null ? _note() : _art(context, size),
    );
  }

  Widget _art(BuildContext context, double size) {
    return TrackArt(
      trackId: id,
      builder: (context, art) {
        if (art == null) return _note();
        return Image.memory(
          art,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _note(),
        );
      },
    );
  }

  Widget _note() {
    return Center(
      child: Image.asset(
        'assets/backgrounds/nota.png',
        width: 120,
        height: 120,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.music_note, color: Colors.white, size: 96),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.ctrl});

  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final total = ctrl.durationMs > 0 ? ctrl.durationMs.toInt() : 1;
    final value = ctrl.position.inMilliseconds.clamp(0, total).toDouble();
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            max: total.toDouble(),
            onChangeEnd: (v) => ctrl.seek(Duration(milliseconds: v.toInt())),
            onChanged: (_) {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(ctrl.position), style: _timeStyle),
              Text(_fmt(Duration(milliseconds: total)), style: _timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  static const _timeStyle = TextStyle(color: Colors.white54, fontSize: 12);

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.ctrl});

  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 26,
          icon: Icon(ctrl.shuffle ? Icons.shuffle : Icons.shuffle,
              color: ctrl.shuffle ? const Color(0xFFE439B3) : Colors.white54),
          onPressed: ctrl.toggleShuffle,
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: ctrl.previous,
        ),
        _PlayButton(ctrl: ctrl),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: ctrl.next,
        ),
        IconButton(
          iconSize: 26,
          icon: Icon(
            ctrl.repeat == RepeatMode.one
                ? Icons.repeat_one
                : Icons.repeat,
            color: ctrl.repeat == RepeatMode.off
                ? Colors.white54
                : const Color(0xFFE439B3),
          ),
          onPressed: () {
            final nextMode = switch (ctrl.repeat) {
              RepeatMode.off => RepeatMode.all,
              RepeatMode.all => RepeatMode.one,
              RepeatMode.one => RepeatMode.off,
            };
            ctrl.setRepeat(nextMode);
          },
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.ctrl});

  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: ctrl.togglePlay,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: PleerDesign.buttonGradient,
          boxShadow: PleerDesign.glow(const Color(0xFFA62AFF)),
        ),
        child: Icon(
          ctrl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 42,
        ),
      ),
    );
  }
}

class _SeekRow extends StatelessWidget {
  const _SeekRow({required this.ctrl});

  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final step = ctrl.seekStepSeconds;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SeekChip(
          icon: Icons.replay_10,
          label: '$step с',
          onTap: () {
            final to = ctrl.position - Duration(seconds: step);
            ctrl.seek(to < Duration.zero ? Duration.zero : to);
          },
        ),
        const SizedBox(width: 20),
        _SeekChip(
          icon: Icons.forward_10,
          label: '$step с',
          onTap: () {
            ctrl.seek(ctrl.position + Duration(seconds: step));
          },
        ),
      ],
    );
  }
}

class _SeekChip extends StatelessWidget {
  const _SeekChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: PleerDesign.brMd,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: PleerDesign.brMd,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
