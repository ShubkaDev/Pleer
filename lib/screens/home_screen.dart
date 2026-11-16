import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../logic/player_controller.dart';
import '../services/favorites_store.dart';
import '../services/playlist_store.dart';
import '../theme/design.dart';
import 'now_playing_screen.dart';
import 'playlists_screen.dart';
import 'recordings_screen.dart';
import 'settings_screen.dart';
import 'video_player_screen.dart';
import 'widgets/app_background.dart';
import 'widgets/glass_card.dart';
import 'widgets/track_art.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _section = 0; // 0 — Аудио, 1 — Видео
  int _audioTab = 0; // 0 — Список, 1 — Записи, 2 — Плейлисты, 3 — Избранное

  // Режим группового выделения (аудио-список)
  final Set<int> _selectedIds = {};
  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<PlayerController>();
      if (ctrl.allTracks.isEmpty) ctrl.refreshLibrary();
      ctrl.refreshRecordings();
    });
  }

  void _ensureVideos() {
    final ctrl = context.read<PlayerController>();
    if (ctrl.videos.isEmpty) ctrl.refreshVideos();
  }

  Future<void> _openRecorderHub() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordingsScreen()),
    );
    if (!mounted) return;
    final ctrl = context.read<PlayerController>();
    await ctrl.refreshRecordings();
    await ctrl.refreshVideos();
  }

  List<Track> _selectedTracks() {
    return context
        .read<PlayerController>()
        .allTracks
        .where((t) => _selectedIds.contains(t.id))
        .toList();
  }

  Future<void> _addSelectedToPlaylist(PlayerController ctrl) async {
    final tracks = _selectedTracks();
    if (tracks.isEmpty) return;
    final pls = PlaylistStore.instance.all;
    if (pls.isEmpty) {
      PlaylistStore.instance.createPlaylist('Мой плейлист');
    }
    final name = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final pl in PlaylistStore.instance.all)
              ListTile(
                title: Text(pl.name),
                onTap: () => Navigator.pop(ctx, pl.id),
              ),
          ],
        ),
      ),
    );
    if (name == null) return;
    for (final t in tracks) {
      PlaylistStore.instance.addTrack(name, t.id);
    }
    setState(_selectedIds.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Добавлено $tracks.length треков в плейлист')),
    );
  }

  Future<void> _deleteSelected(PlayerController ctrl) async {
    final tracks = _selectedTracks();
    if (tracks.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141F),
        title: const Text('Удалить файлы?'),
        content: Text('$tracks.length файлов'),
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
    );
    if (ok != true) return;
    var deleted = 0;
    for (final t in tracks) {
      if (await ctrl.deleteMedia(t)) deleted++;
    }
    setState(_selectedIds.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted > 0 ? 'Удалено: $deleted' : 'Нечего удалять')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final hasTrack = ctrl.currentTrack != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _RecordFab(onTap: _openRecorderHub),
      body: SafeArea(
        bottom: false,
        child: Column(
            children: [
              if (_selectionMode)
                _SelectionBar(
                  count: _selectedIds.length,
                  onClose: () => setState(_selectedIds.clear),
                  onAddToPlaylist: () => _addSelectedToPlaylist(ctrl),
                  onDelete: () => _deleteSelected(ctrl),
                )
              else
                _Header(
                  onSearch: () => _openSearch(ctrl),
                  onSettings: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              _SectionTabs(
                section: _section,
                onChanged: (s) {
                  setState(() => _section = s);
                  if (s == 1) _ensureVideos();
                },
              ),
              if (_section == 0)
                _AudioTabs(
                  audioTab: _audioTab,
                  onChanged: (t) => setState(() => _audioTab = t),
                ),
              Expanded(
                child: _section == 0
                    ? _audioContent(ctrl)
                    : _videoContent(ctrl),
              ),
            ],
          ),
      ),
      bottomNavigationBar: hasTrack ? _PlayerBar(ctrl: ctrl) : null,
    );
  }

  Widget _audioContent(PlayerController ctrl) {
    if (_audioTab == 1) {
      return _RecordingsTab(
        recordings: ctrl.recordings,
        onRefresh: ctrl.refreshRecordings,
        onPlay: (i) => ctrl.playTracks(ctrl.recordings, startIndex: i),
        onDelete: ctrl.deleteRecording,
        onRecord: _openRecorderHub,
      );
    }
    if (_audioTab == 2) {
      return _PlaylistsTab();
    }
    final source = _audioTab == 3
        ? ctrl.allTracks
            .where((t) => FavoritesStore.instance.isFavorite(t.id))
            .toList()
        : ctrl.allTracks;

    if (ctrl.allTracks.isEmpty) {
      return _EmptyState(
        icon: Icons.library_music_outlined,
        text: _audioTab == 3
            ? 'Нет избранных треков'
            : 'Музыка не найдена. Нажмите «Обновить».',
        actionLabel: 'Обновить',
        onAction: () => ctrl.refreshLibrary(),
      );
    }
    if (source.isEmpty) {
      return _EmptyState(
        icon: Icons.favorite_border,
        text: 'Нет избранных треков',
        actionLabel: 'К списку',
        onAction: () => setState(() => _audioTab = 0),
      );
    }
    return RefreshIndicator(
      onRefresh: ctrl.refreshLibrary,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 16),
        itemCount: source.length,
        itemBuilder: (context, i) => _TrackRow(
          track: source[i],
          index: i,
          list: source,
          selectionMode: _selectionMode,
          isSelected: _selectedIds.contains(source[i].id),
          onLongPress: () {
            setState(() {
              _selectedIds.add(source[i].id);
            });
          },
          onToggleSelected: () {
            setState(() {
              if (!_selectedIds.remove(source[i].id)) {
                _selectedIds.add(source[i].id);
              }
            });
          },
        ),
      ),
    );
  }

  Widget _videoContent(PlayerController ctrl) {
    if (ctrl.videos.isEmpty) {
      return _EmptyState(
        icon: Icons.video_library_outlined,
        text: 'Видео не найдено',
        actionLabel: 'Обновить',
        onAction: () => ctrl.refreshVideos(),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: ctrl.videos.length,
      itemBuilder: (context, i) {
        final v = ctrl.videos[i];
        return _VideoCard(video: v, videos: ctrl.videos);
      },
    );
  }

  void _openSearch(PlayerController ctrl) {
    showSearch<String>(
      context: context,
      delegate: _TrackSearchDelegate(ctrl.allTracks, ctrl),
    );
  }
}

// ---------- Шапка ----------

class _Header extends StatelessWidget {
  const _Header({required this.onSearch, required this.onSettings});

  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => PleerDesign.buttonGradient.createShader(bounds),
            child: const Text(
              'Pleer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: onSearch,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

// ---------- Вкладки ----------

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.section, required this.onChanged});

  final int section;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          _tab('Аудио', section == 0, () => onChanged(0)),
          const SizedBox(width: 22),
          _tab('Видео', section == 1, () => onChanged(1)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 3,
              width: active ? 42 : 0,
              decoration: BoxDecoration(
                gradient: PleerDesign.buttonGradient,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioTabs extends StatelessWidget {
  const _AudioTabs({required this.audioTab, required this.onChanged});

  final int audioTab;
  final ValueChanged<int> onChanged;

  static const _labels = ['Список', 'Записи', 'Плейлисты', 'Избранное'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _labels.length,
        itemBuilder: (context, i) {
          final active = i == audioTab;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                gradient: active ? PleerDesign.buttonGradient : null,
                color: active ? null : Colors.black.withValues(alpha: 0.22),
                borderRadius: PleerDesign.brLg,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Center(
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------- Панель группового выделения ----------

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClose,
    required this.onAddToPlaylist,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: onClose,
            ),
            Expanded(
              child: Text(
                'Выбрано: $count',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.white70),
              tooltip: 'В плейлист',
              onPressed: onAddToPlaylist,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Удалить',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Строка трека ----------

class _TrackRow extends StatefulWidget {
  const _TrackRow({
    required this.track,
    required this.index,
    required this.list,
    this.selectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onToggleSelected,
  });

  final Track track;
  final int index;
  final List<Track> list;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelected;

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<PlayerController>();
    final t = widget.track;
    final isFav = FavoritesStore.instance.isFavorite(t.id);
    final isCurrent = ctrl.currentId == t.id;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
        leading: widget.selectionMode
            ? Icon(
                widget.isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: widget.isSelected
                    ? const Color(0xFFF26BD0)
                    : Colors.white54,
              )
            : _NoteAvatar(track: t),
        title: Text(
          t.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? const Color(0xFFF26BD0) : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          t.displayArtist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        trailing: widget.selectionMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rowIcon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    isFav ? const Color(0xFFF26BD0) : Colors.white70,
                    () {
                      FavoritesStore.instance.toggle(t.id);
                      setState(() {});
                    },
                  ),
                  _rowIcon(Icons.more_vert, Colors.white70,
                      () => _showMenu(context, t)),
                  _rowIcon(Icons.play_arrow_rounded, Colors.white, () {
                    ctrl.playTracks(widget.list, startIndex: widget.index);
                  }),
                ],
              ),
        onTap: widget.selectionMode
            ? widget.onToggleSelected
            : () => ctrl.playTracks(widget.list, startIndex: widget.index),
        onLongPress: widget.onLongPress,
      ),
    );
  }

  Widget _rowIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }

  void _showMenu(BuildContext context, Track t) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Добавить в плейлист'),
              onTap: () {
                Navigator.pop(ctx);
                _addToPlaylist(context, t);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Сведения'),
              onTap: () {
                Navigator.pop(ctx);
                _showInfo(context, t);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_in_talk_outlined),
              title: const Text('Мелодия звонка'),
              onTap: () {
                Navigator.pop(ctx);
                _setAsRingtone(context, t);
              },
            ),
            if (t.data.startsWith('content://'))
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Переименовать'),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameMedia(context, t);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMedia(context, t);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameMedia(BuildContext context, Track t) async {
    final controller = TextEditingController(
        text: t.displayTitle.replaceAll(RegExp(r'\.[^.]+$'), ''));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141F),
        title: const Text('Переименовать'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Новое имя'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    final ok = await context.read<PlayerController>().renameMedia(t, newName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Переименовано' : 'Не удалось переименовать')),
    );
  }

  Future<void> _deleteMedia(BuildContext context, Track t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141F),
        title: const Text('Удалить файл?'),
        content: Text(t.displayTitle),
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
    );
    if (confirm != true) return;
    final ctrl = context.read<PlayerController>();
    final ok = await ctrl.deleteMedia(t);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Файл удалён' : 'Не удалось удалить файл')),
    );
  }

  Future<void> _setAsRingtone(BuildContext context, Track t) async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Доступно только на Android')),
      );
      return;
    }
    final ctrl = context.read<PlayerController>();
    if (!await ctrl.canWriteSettings()) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Нужен доступ к настройкам'),
          content: const Text(
              'Чтобы установить мелодию звонка, разрешите приложению '
              'изменять системные настройки, затем повторите действие.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Разрешить'),
            ),
          ],
        ),
      );
      if (go != true) return;
      await ctrl.requestWriteSettings();
      return;
    }
    final ok = await ctrl.setAsRingtone(t);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Установлено как мелодия звонка' : 'Не удалось установить мелодию')),
    );
  }

  void _addToPlaylist(BuildContext context, Track t) {
    final pls = PlaylistStore.instance.all;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final pl in pls)
              ListTile(
                title: Text(pl.name),
                onTap: () {
                  PlaylistStore.instance.addTrack(pl.id, t.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, Track t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: PleerDesign.brandGradient,
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.displayTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _info('Исполнитель', t.displayArtist),
            _info('Альбом', t.displayAlbum),
            _info('Файл', t.data),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF5716FF),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$k: $v',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5)),
      );
}

class _NoteAvatar extends StatelessWidget {
  const _NoteAvatar({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return TrackArt(
      trackId: track.id,
      builder: (context, art) => Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: PleerDesign.brandGradientSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: (art == null)
            ? const Icon(Icons.music_note, color: Colors.white, size: 24)
            : Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}

// ---------- Плейлисты ----------

class _PlaylistsTab extends StatefulWidget {
  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
  void _create() {
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final name = tc.text.trim();
              if (name.isNotEmpty) PlaylistStore.instance.createPlaylist(name);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pls = PlaylistStore.instance.all;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Создать плейлист'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: pls.isEmpty
              ? _EmptyState(
                  icon: Icons.queue_music,
                  text: 'Плейлистов пока нет',
                  actionLabel: 'Создать',
                  onAction: _create,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: pls.length,
                  itemBuilder: (context, i) {
                    final pl = pls[i];
                    return GlassCard(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          child: const Icon(Icons.queue_music,
                              color: Colors.white),
                        ),
                        title: Text(pl.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        subtitle: Text('${pl.trackIds.length} треков',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6))),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white54),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlaylistDetailScreen(playlistId: pl.id),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------- Видео ----------

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.videos});

  final VideoItem video;
  final List<VideoItem> videos;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(video: video, playlist: videos),
        ),
      ),
      onLongPress: () => _menu(context),
      child: ClipRRect(
        borderRadius: PleerDesign.brMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: PleerDesign.brandGradientSoft),
            ),
            const Center(
              child: Icon(Icons.movie, color: Colors.white54, size: 42),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 52),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Text(
                  video.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.38),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _menu(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_vert, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _menu(BuildContext outer) {
    showModalBottomSheet(
      context: outer,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Воспроизвести'),
              onTap: () {
                Navigator.pop(ctx);
                final nav = Navigator.of(outer);
                nav.push(MaterialPageRoute(
                  builder: (_) =>
                      VideoPlayerScreen(video: video, playlist: videos),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить с устройства',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(outer);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext outer) async {
    final ok = await showDialog<bool>(
      context: outer,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить видео?'),
        content: Text(video.displayTitle),
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
        final f = File(video.data);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      if (outer.mounted) {
        outer.read<PlayerController>().refreshVideos();
      }
    }
  }
}

// ---------- Нижняя панель плеера ----------

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.ctrl});

  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PleerDesign.darkBg.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: PleerDesign.brandGradientSoft,
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ctrl.currentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5)),
                      Text(ctrl.currentArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11.5)),
                    ],
                  ),
                ),
                Text(
                  _fmt(ctrl.position),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 10),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: ctrl.togglePlay,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: PleerDesign.buttonGradient,
                      boxShadow: PleerDesign.glow(const Color(0xFFA62AFF)),
                    ),
                    child: Icon(
                      ctrl.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ---------- Кнопка записи (лучшее место: круг внизу справа) ----------

class _RecordFab extends StatelessWidget {
  const _RecordFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: PleerDesign.glow(const Color(0xFFE439B3)),
      ),
      child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        elevation: 0,
        onPressed: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: PleerDesign.buttonGradient,
          ),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.fiber_manual_record, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

// ---------- Вкладка «Записи» ----------

class _RecordingsTab extends StatelessWidget {
  const _RecordingsTab({
    required this.recordings,
    required this.onRefresh,
    required this.onPlay,
    required this.onDelete,
    required this.onRecord,
  });

  final List<Track> recordings;
  final Future<void> Function() onRefresh;
  final void Function(int index) onPlay;
  final Future<void> Function(Track track) onDelete;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) {
      return _EmptyState(
        icon: Icons.mic_none,
        text: 'Здесь появятся ваши аудиозаписи',
        actionLabel: 'Записать',
        onAction: onRecord,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 16),
        itemCount: recordings.length,
        itemBuilder: (context, i) {
          final r = recordings[i];
          final color = Theme.of(context).colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => onPlay(i),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: PleerDesign.buttonGradient,
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onPlay(i),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Аудиозапись Pleer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.white54,
                    tooltip: 'Удалить',
                    onPressed: () => _confirmDelete(context, r),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Track track) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(track.title),
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
    );
    if (ok == true) await onDelete(track);
  }
}

// ---------- Пустое состояние ----------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white38),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

// ---------- Поиск ----------

class _TrackSearchDelegate extends SearchDelegate<String> {
  _TrackSearchDelegate(this.tracks, this.ctrl);

  final List<Track> tracks;
  final PlayerController ctrl;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  List<Track> _results() {
    final q = query.toLowerCase();
    return tracks
        .where((t) =>
            t.displayTitle.toLowerCase().contains(q) ||
            t.displayArtist.toLowerCase().contains(q) ||
            t.displayAlbum.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) =>
      query.isEmpty ? const Center(child: Text('Введите название или исполнителя')) : _list(context);

  Widget _list(BuildContext context) {
    final res = _results();
    if (res.isEmpty) return const Center(child: Text('Ничего не найдено'));
    return ListView.builder(
      itemCount: res.length,
      itemBuilder: (context, i) {
        final t = res[i];
        return ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(t.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(t.displayArtist, maxLines: 1),
          onTap: () {
            ctrl.playTracks(res, startIndex: i);
            close(context, '');
          },
        );
      },
    );
  }
}
