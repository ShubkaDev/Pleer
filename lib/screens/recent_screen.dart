import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../logic/player_controller.dart';
import '../services/favorites_store.dart';
import 'widgets/glass_card.dart';
import 'widgets/track_art.dart';

/// Недавно прослушанные треки (по истории воспроизведения).
class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final ids = HistoryStore.instance.recent;
    final byId = {for (final t in ctrl.allTracks) t.id: t};
    final tracks = ids.map((id) => byId[id]).whereType<Track>().toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Недавние')),
      body: tracks.isEmpty
          ? const Center(
              child: Text(
                'Здесь появятся недавно прослушанные треки',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final t = tracks[i];
                return _RecentTile(index: i, track: t, tracks: tracks);
              },
            ),
    );
  }
}

class _RecentTile extends StatefulWidget {
  const _RecentTile({
    required this.index,
    required this.track,
    required this.tracks,
  });

  final int index;
  final Track track;
  final List<Track> tracks;

  @override
  State<_RecentTile> createState() => _RecentTileState();
}

class _RecentTileState extends State<_RecentTile> {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<PlayerController>();
    final t = widget.track;
    final isFav = FavoritesStore.instance.isFavorite(t.id);
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _Artwork(id: t.id, size: 46),
        title: Text(t.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
        subtitle: Text(t.displayArtist,
            maxLines: 1,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        trailing: IconButton(
          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? const Color(0xFFF26BD0) : Colors.white70),
          onPressed: () {
            FavoritesStore.instance.toggle(t.id);
            setState(() {});
          },
        ),
        onTap: () => ctrl.playTracks(widget.tracks, startIndex: widget.index),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.id, required this.size});

  final int? id;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (id == null) return _placeholder(context);
    return TrackArt(
      trackId: id,
      builder: (context, art) {
        if (art == null) return _placeholder(context);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(art,
              width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
