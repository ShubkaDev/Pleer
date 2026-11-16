import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../data/models.dart';
import '../logic/player_controller.dart';
import 'video_player_screen.dart';

class VideosLibraryScreen extends StatefulWidget {
  const VideosLibraryScreen({super.key});

  @override
  State<VideosLibraryScreen> createState() => _VideosLibraryScreenState();
}

class _VideosLibraryScreenState extends State<VideosLibraryScreen> {
  List<VideoItem>? _videos;
  Future<void>? _scanFuture;

  @override
  void initState() {
    super.initState();
    _scanFuture = _scan();
  }

  Future<void> _scan() async {
    final ctrl = context.read<PlayerController>();
    await ctrl.refreshVideos();
    if (mounted) setState(() => _videos = ctrl.videos);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Видеотека'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Пересканировать',
            onPressed: () => setState(() => _scanFuture = _scan()),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _scanFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = _videos ?? ctrl.videos;
          if (list.isEmpty) {
            return const Center(
              child: Text('Видео не найдено', style: TextStyle(color: Colors.grey)),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final v = list[i];
              return _VideoCard(video: v, videos: list);
            },
          );
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.videos});

  final VideoItem video;
  final List<VideoItem> videos;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<PlayerController>();
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              video: video,
              playlist: videos,
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: ctrl.library.videoThumbnail(video.id),
              builder: (context, snap) {
                final data = snap.data;
                if (data == null || data.isEmpty) {
                  return Container(
                    color: Colors.black,
                    child: const Icon(Icons.movie, color: Colors.white54),
                  );
                }
                return Image.memory(data, fit: BoxFit.cover);
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                color: Colors.black.withOpacity(0.6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Text(
                      _fmt(video.durationMs),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}