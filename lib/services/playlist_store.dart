import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../data/models.dart';

class PlaylistStore {
  PlaylistStore._();
  static final PlaylistStore instance = PlaylistStore._();

  late Box<Playlist> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Playlist>('playlists');
  }

  List<Playlist> get all => _box.values.toList();

  Playlist createPlaylist(String name) {
    final pl = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      name: name,
      trackIds: <int>[],
    );
    _box.put(pl.id, pl);
    return pl;
  }

  void addTrack(String playlistId, int trackId) {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    if (pl.trackIds.contains(trackId)) return;
    pl.trackIds = [...pl.trackIds, trackId];
    _box.put(pl.id, pl);
  }

  void removeTrack(String playlistId, int trackId) {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    pl.trackIds = pl.trackIds.where((t) => t != trackId).toList();
    _box.put(pl.id, pl);
  }

  void reorder(String playlistId, int oldIndex, int newIndex) {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    final ids = [...pl.trackIds];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    pl.trackIds = ids;
    _box.put(pl.id, pl);
  }

  void rename(String playlistId, String newName) {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    pl.name = newName;
    _box.put(pl.id, pl);
  }

  void delete(String playlistId) {
    _box.delete(playlistId);
  }
}