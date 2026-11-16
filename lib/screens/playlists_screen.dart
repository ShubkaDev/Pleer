import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../logic/player_controller.dart';
import '../services/playlist_store.dart';
import 'widgets/glass_card.dart';
import 'widgets/track_art.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = PlaylistStore.instance;
    final pls = store.all;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Плейлисты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Новый плейлист',
            onPressed: _createPlaylist,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPlaylist,
        child: const Icon(Icons.add),
      ),
      body: pls.isEmpty
          ? const Center(
              child: Text('Плейлистов пока нет',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              itemCount: pls.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final pl = pls[i];
                return Dismissible(
                  key: ValueKey(pl.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить плейлист?'),
                            content: Text('«${pl.name}» будет удалён'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) => store.delete(pl.id),
                  child: GlassCard(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        child: Icon(
                          pl.trackIds.isNotEmpty
                              ? Icons.queue_music
                              : Icons.queue_music_outlined,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(pl.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text('${pl.trackIds.length} треков',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6))),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white54),
                      onTap: () => _openPlaylist(pl),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _createPlaylist() {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый плейлист'),
        content: TextField(
          controller: tc,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = tc.text.trim();
              if (name.isNotEmpty) {
                PlaylistStore.instance.createPlaylist(name);
              }
              Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _openPlaylist(Playlist pl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
      ),
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final store = PlaylistStore.instance;
    final ctrl = context.watch<PlayerController>();

    final pl = store.all.firstWhere(
        (p) => p.id == widget.playlistId,
        orElse: () =>
            Playlist(id: widget.playlistId, name: 'Удалён', trackIds: []));

    final tracksById = {for (final t in ctrl.allTracks) t.id: t};
    final playlistTracks = pl.trackIds
        .map((id) => tracksById[id])
        .whereType<Track>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(pl.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Переименовать',
            onPressed: () => _rename(pl),
          ),
        ],
      ),
      body: playlistTracks.isEmpty
          ? const Center(
              child: Text('Плейлист пуст', style: TextStyle(color: Colors.grey)),
            )
          : ReorderableListView.builder(
              itemCount: playlistTracks.length,
              onReorder: (oldI, newI) {
                store.reorder(widget.playlistId, oldI, newI);
                setState(() {});
              },
              itemBuilder: (context, i) {
                final t = playlistTracks[i];
                return ListTile(
                  key: ValueKey('${pl.id}_$i'),
                  leading: _Artwork(id: t.id, size: 44),
                  title: Text(t.displayTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(t.displayArtist,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    ctrl.playTracks(playlistTracks, startIndex: i);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      store.removeTrack(widget.playlistId, t.id);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }

  void _rename(Playlist pl) {
    final store = PlaylistStore.instance;
    final tc = TextEditingController(text: pl.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать'),
        content: TextField(
          controller: tc,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = tc.text.trim();
              if (name.isNotEmpty) store.rename(widget.playlistId, name);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
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
