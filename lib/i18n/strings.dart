import 'package:flutter/material.dart';

/// Локализация приложения: Русский, English, 中文.
class AppStrings {
  AppStrings(this._code);

  final String _code;

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  String get music => _pick('Музыка', 'Music', '音乐');
  String get videos => _pick('Видео', 'Videos', '视频');
  String get recordings => _pick('Записи', 'Recordings', '录音');
  String get playlists => _pick('Плейлисты', 'Playlists', '播放列表');
  String get settings => _pick('Настройки', 'Settings', '设置');
  String get recordAudio => _pick('Запись звука', 'Record audio', '录音');
  String get recordScreen => _pick('Запись экрана', 'Screen record', '屏幕录制');
  String get recordCamera => _pick('Запись камеры', 'Camera record', '相机录制');
  String get myMusic => _pick('Моя музыка', 'My music', '我的音乐');
  String get videoLibrary => _pick('Видеотека', 'Video library', '视频库');
  String get nothingPlaying => _pick('Ничего не играет', 'Nothing playing', '没有正在播放');
  String get eq => _pick('Эквалайзер', 'Equalizer', '均衡器');
  String get sleepTimer => _pick('Таймер сна', 'Sleep timer', '睡眠定时器');
  String get speed => _pick('Скорость', 'Speed', '速度');
  String get notFound => _pick('Не найдено', 'Not found', '未找到');

  String _pick(String ru, String en, String zh) {
    switch (_code) {
      case 'en':
        return en;
      case 'zh':
        return zh;
      default:
        return ru;
    }
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ru', 'en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async =>
      AppStrings(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}