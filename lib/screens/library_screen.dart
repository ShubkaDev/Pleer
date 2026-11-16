import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../logic/player_controller.dart';
import '../services/favorites_store.dart';
import '../services/playlist_store.dart';
import 'now_playing_screen.dart';
import 'widgets/glass_card.dart';
import 'widgets/track_art.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Track>? _tracks;
  Future<void>? _scanFuture;
  String _query = '';
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<PlayerController>();
    if (ctrl.allTracks.isNotEmpty) {
      _tracks = ctrl.allTracks;
    } else {
      _scanFuture = _scan();
    }
  }

  Future<void> _scan() async {
    final ctrl = context.read<PlayerController>();
    await ctrl.refreshLibrary();
    if (mounted) setState(() => _tracks = ctrl.allTracks);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Моя музыка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Поиск',
            onPressed: () async {
              final q = await showSearch<String>(
                context: context,
                delegate: _TrackSearchDelegate(ctrl.allTracks),
              );
              if (q != null) {
                setState(() => _query = q);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Пересканировать',
            onPressed: () => setState(() => _scanFuture = _scan()),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            favoritesOnly: _favoritesOnly,
            onToggleFavorites: (v) => setState(() => _favoritesOnly = v),
            ctrl: context.read<PlayerController>(),
          ),
          Expanded(child: _body(ctrl)),
        ],
      ),
    );
  }

  List<Track> _filtered(List<Track> list) {
    var out = ctrlSort(list);
    if (_favoritesOnly) {
      out = out
          .where((t) => FavoritesStore.instance.isFavorite(t.id))
          .toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      out = out
          .where((t) =>
              t.displayTitle.toLowerCase().contains(q) ||
              t.displayArtist.toLowerCase().contains(q) ||
              t.displayAlbum.toLowerCase().contains(q))
          .toList();
    }
    return out;
  }

  List<Track> ctrlSort(List<Track> list) {
    final c = context.read<PlayerController>();
    return c.sortTracks(list);
  }

  Widget _body(PlayerController ctrl) {
    if (_scanFuture != null) {
      return FutureBuilder(
        future: _scanFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = _filtered(_tracks ?? ctrl.allTracks);
          if (list.isEmpty) {
            return _favoritesOnly
                ? const _EmptyFavorites()
                : const _EmptyLibrary();
          }
          return _TrackList(tracks: list);
        },
      );
    }
    final list = _filtered(_tracks ?? ctrl.allTracks);
    if (list.isEmpty) return _favoritesOnly ? const _EmptyFavorites() : const _EmptyLibrary();
    return _TrackList(tracks: list);
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.favoritesOnly,
    required this.onToggleFavorites,
    required this.ctrl,
  });

  final bool favoritesOnly;
  final ValueChanged<bool> onToggleFavorites;
  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('♥ Избранное'),
            selected: favoritesOnly,
            onSelected: onToggleFavorites,
          ),
          const SizedBox(width: 8),
          const Spacer(),
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: 'Сортировка',
            onSelected: (mode) => ctrl.setSortMode(mode),
            itemBuilder: (ctx) => [
              for (final m in SortMode.values)
                PopupMenuItem(
                  value: m,
                  child: Row(
                    children: [
                      Icon(
                        m == SortMode.title
                            ? Icons.sort_by_alpha
                            : m == SortMode.artist
                                ? Icons.person
                                : m == SortMode.album
                                    ? Icons.album
                                    : m == SortMode.dateAdded
                                        ? Icons.date_range
                                        : Icons.timer_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(_sortLabel(m)),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(
              ctrl.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            tooltip: 'Порядок',
            onPressed: () => ctrl.setSortAscending(!ctrl.sortAscending),
          ),
        ],
      ),
    );
  }

  String _sortLabel(SortMode m) {
    switch (m) {
      case SortMode.title:
        return 'По названию';
      case SortMode.artist:
        return 'По исполнителю';
      case SortMode.album:
        return 'По альбому';
      case SortMode.dateAdded:
        return 'По дате';
      case SortMode.duration:
        return 'По длительности';
    }
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Нет избранных треков', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Делегат поиска по трекам.
class _TrackSearchDelegate extends SearchDelegate<String> {
  final List<Track> tracks;
  _TrackSearchDelegate(this.tracks);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) {
    final q = query.toLowerCase();
    final res = tracks
        .where((t) =>
            t.displayTitle.toLowerCase().contains(q) ||
            t.displayArtist.toLowerCase().contains(q) ||
            t.displayAlbum.toLowerCase().contains(q))
        .toList();
    return _SearchResults(tracks: res, onPick: (track, list) {
      final pc = context.read<PlayerController>();
      pc.playTracks(list, startIndex: list.indexOf(track));
      close(context, '');
    });
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Введите название, исполнителя или альбом'),
      );
    }
    return buildResults(context);
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.tracks, required this.onPick});

  final List<Track> tracks;
  final void Function(Track, List<Track>) onPick;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final t = tracks[i];
        return ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(t.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${t.displayArtist} — ${t.displayAlbum}', maxLines: 1),
          onTap: () => onPick(t, tracks),
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Музыка не найдена',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Проверьте права доступа к файлам или добавьте аудио на устройство, '
              'затем нажмите «Пересканировать».',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final t = tracks[i];
        return _TrackTile(track: t, index: i, queue: tracks);
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.index,
    required this.queue,
  });

  final Track track;
  final int index;
  final List<Track> queue;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final isCurrent = ctrl.currentId == track.id;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _Artwork(id: track.id, size: 46),
        title: Text(
          track.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            color: isCurrent ? const Color(0xFFF26BD0) : Colors.white,
          ),
        ),
        subtitle: Text(
          '${track.displayArtist} · ${track.displayAlbum}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          onPressed: () => _showMenu(context, track),
        ),
        onTap: () {
          ctrl.playTracks(queue, startIndex: index);
        },
      ),
    );
  }

  void _showMenu(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatefulBuilder(
              builder: (ctx, setSheet) => ListTile(
                leading: Icon(
                  FavoritesStore.instance.isFavorite(track.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: FavoritesStore.instance.isFavorite(track.id)
                      ? Colors.red
                      : null,
                ),
                title: Text(
                  FavoritesStore.instance.isFavorite(track.id)
                      ? 'Убрать из избранного'
                      : 'В избранное',
                ),
                onTap: () {
                  FavoritesStore.instance.toggle(track.id);
                  setSheet(() {});
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Добавить в плейлист'),
              onTap: () {
                Navigator.pop(ctx);
                _addToPlaylist(context, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Подробнее'),
              onTap: () {
                Navigator.pop(ctx);
                _showInfo(context, track);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addToPlaylist(BuildContext context, Track track) {
    final store = PlaylistStore.instance;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final pls = store.all;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Выберите плейлист',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final pl in pls)
                ListTile(
                  title: Text(pl.name),
                  onTap: () {
                    store.addTrack(pl.id, track.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Добавлено в «${pl.name}»')),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Новый плейлист'),
                onTap: () {
                  Navigator.pop(ctx);
                  _createPlaylist(context, track);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _createPlaylist(BuildContext context, Track track) {
    final store = PlaylistStore.instance;
    showDialog(
      context: context,
      builder: (ctx) {
        final tc = TextEditingController();
        return AlertDialog(
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
                  final pl = store.createPlaylist(name);
                  store.addTrack(pl.id, track.id);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
  }

  void _showInfo(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.only(top: 40),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F208D),
                Color(0xFF5716FF),
                Color(0xFFA62AFF),
                Color(0xFFE439B3),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              _Artwork(id: track.id, size: 140),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  track.displayTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _infoRow(Icons.person, 'Исполнитель', track.displayArtist),
              ),
              _infoRow(Icons.album, 'Альбом', track.displayAlbum),
              _infoRow(Icons.schedule, 'Длительность', _fmt(track.durationMs)),
              _infoRow(Icons.insert_drive_file, 'Файл', track.data),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5716FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Закрыть',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 220,
            child: Text(
              value,
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.id, required this.size});

  final int? id;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (id == null) {
      return _placeholder(context);
    }
    return TrackArt(
      trackId: id,
      builder: (context, art) {
        if (art == null) return _placeholder(context);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            art,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _placeholder(context),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
