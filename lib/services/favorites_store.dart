import 'package:hive_flutter/hive_flutter.dart';

/// Избранные треки (лайки). Хранятся по MediaStore-ID трека.
class FavoritesStore {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  late Box<bool> _box;

  Future<void> init() async {
    _box = await Hive.openBox<bool>('favorites');
  }

  Set<int> get ids => _box.keys.cast<int>().toSet();

  bool isFavorite(int trackId) => _box.get(trackId) ?? false;

  void toggle(int trackId) {
    if (isFavorite(trackId)) {
      _box.delete(trackId);
    } else {
      _box.put(trackId, true);
    }
  }

  void add(int trackId) => _box.put(trackId, true);

  void remove(int trackId) => _box.delete(trackId);
}

/// История воспроизведения и последняя позиция каждого трека.
class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  late Box<int> _positionBox; // trackId -> позиция (сек)
  late Box _recentBox; // список последних id через separated string

  Future<void> init() async {
    _positionBox = await Hive.openBox<int>('track_positions');
    _recentBox = await Hive.openBox('recent');
  }

  int positionOf(int trackId) => _positionBox.get(trackId) ?? 0;

  Future<void> savePosition(int trackId, int seconds) async {
    if (seconds <= 0) return;
    await _positionBox.put(trackId, seconds);
  }

  /// Сохраняет трек в начале истории (максимум N последних).
  Future<void> pushRecent(int trackId) async {
    final list = recent.toList();
    list.remove(trackId);
    list.insert(0, trackId);
    if (list.length > 50) list.removeRange(50, list.length);
    await _recentBox.put('ids', list.join(','));
  }

  List<int> get recent {
    final raw = _recentBox.get('ids', defaultValue: '');
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map(int.parse).whereType<int>().toList();
  }
}