import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Track {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final String data; // путь к файлу
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String artist;
  @HiveField(4)
  final String album;
  @HiveField(5)
  final int durationMs;
  @HiveField(6)
  final int dateAdded;

  Track({
    required this.id,
    required this.data,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.dateAdded,
  });

  String get displayTitle =>
      title.isNotEmpty ? title : (data.split('/').last.split('\\').last);

  String get displayArtist =>
      artist.isNotEmpty ? artist : 'Неизвестный исполнитель';

  String get displayAlbum =>
      album.isNotEmpty ? album : 'Неизвестный альбом';
}

@HiveType(typeId: 1)
class Playlist {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  List<int> trackIds;

  Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
  });
}

/// Видеофайл, найденный в медиатеке.
class VideoItem {
  final int id;
  final String data;
  final String title;
  final String album;
  final String artist;
  final int durationMs;
  final int size;
  final int dateAdded;

  VideoItem({
    required this.id,
    required this.data,
    required this.title,
    required this.album,
    required this.artist,
    required this.durationMs,
    required this.size,
    required this.dateAdded,
  });

  String get displayTitle =>
      title.isNotEmpty ? title : (data.split('/').last.split('\\').last);
}