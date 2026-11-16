# Pleer — Универсальный Медиа-центр

Полнофункциональное медиа-приложение на Flutter для **Android** и **Windows**:
аудио- и видеоплеер, запись звука, экрана и камеры — в одном приложении.
Все «Pro»-функции включены сразу, без разграничения и оплаты.

## 📱 Возможности

### 🎵 Аудио Плеер
- Качественное воспроизведение музыки (`just_audio`).
- Встроенный эквалайзер: 5 полос + **16 пресетов** (Flat, Rock, Pop, Jazz,
  Classic, Bass boost, Treble, Vocal, Dance, Hip-Hop, Metal, Acoustic,
  Podcast, Loudness, Soft, Electronic), Bass Boost и **кастомные пресеты**
  (сохранение/применение/удаление).
- Нормализация звука (выравнивание громкости треков).
- Сканирование библиотеки через MediaStore (`on_audio_query`), обложки.
- Сортировки по названию / исполнителю / альбому / папке / дате / длительности
  с направлением (↑/↓).
- **Поиск** по названию, исполнителю, альбому (SearchDelegate).
- **Избранное (♥)**: добавление треков, фильтр «только избранное».
- **Недавние**: история последних прослушанных треков.
- **Плейлисты**: создание, добавление, drag&drop порядок, переименование,
  удаление (Hive).
- **Очередь воспроизведения**: просмотр, перестановка, удаление треков.
- **Память позиции** (для подкастов/аудиокниг): продолжение с места остановки.
- Фоновое воспроизведение (`audio_service`) + уведомление с кнопками.
- Пауза при отключении наушников, случайный порядок, повтор (все/один/выкл).
- **Автопереход к следующему** (вкл/выкл).
- **Шаг перемотки** (±5/10/15/30 с) — настраиваемые кнопки в плеере.
- Скорость 0.5x–3x (для лекций/аудиокниг).
- Таймер сна с плавным затуханием громкости.
- **Gapless** (бесшовное) и **кроссфейд** (2–8 c) — настройки.
- Чтение ID3-тегов (нативный `MediaMetadataRetriever`).

### 🎥 Видео Плеер
- Просмотр видео в высоком качестве (`video_player` + `chewie`).
- Миниатюры из медиатеки (MediaStore).
- Режим «Картинка в картинке» (PiP, Android 8+).
- Автоповорот экрана.

### 🎙️ Инструменты Записи
- **Запись звука**: `record`, сохранение с микрофона (m4a) в папку записей.
- **Запись экрана**: нативный `MediaProjection` + `MediaRecorder` (MPEG-4/H264),
  фоновый сервис с уведомлением (Android 10+).
- **Запись с камеры**: `camera`, запись видео (mp4), переключение камер.

### 📂 Медиатека и Удобство
- Автоматическое сканирование памяти на аудио и видео.
- Современный дизайн Material 3, тёмная/светлая/системная тема.
- Динамические цвета «Material You» (Android 12+, цвет из обоев).
- Многоязычность: **Русский, English, 中文**.
- Настраиваемый шаг перемотки, автопереход, gapless, кроссфейд.

## Структура

```
lib/
  main.dart                    — инициализация, запуск, локализация
  i18n/strings.dart            — переводы (ru/en/zh)
  data/models.dart             — Track, VideoItem, Playlist
  logic/player_controller.dart — весь плеер + состояния
  services/
    library_service.dart       — сканирование аудио/видео, обложки
    playlist_store.dart        — плейлисты (Hive)
    favorites_store.dart       — избранное + история/позиции (Hive)
    equalizer_helper.dart      — MethodChannel к нативному эквалайзеру
    tags_service.dart          — чтение/запись ID3
    recorder_controller.dart   — запись звука
    screen_recorder_controller.dart — запись экрана
  screens/
    home_screen.dart           — навигация (6 вкладок) + мини-плеер
    library_screen.dart        — музыка (поиск, избранное, сортировка)
    recent_screen.dart         — недавние треки
    queue_screen.dart          — очередь воспроизведения
    videos_library_screen.dart — видеотека
    video_player_screen.dart   — видеоплеер (PiP, автоповорот)
    playlists_screen.dart      — плейлисты
    recordings_screen.dart     — хаб записи
    audio_recorder_screen.dart — запись звука
    screen_recorder_screen.dart— запись экрана
    camera_recorder_screen.dart— запись с камеры
    now_playing_screen.dart    — «карточный» аудиоплеер
    equalizer_screen.dart      — эквалайзер
    settings_screen.dart       — настройки (тема, язык, нормализация…)
  theme/app_theme.dart         — Material 3 + dynamic color
android/…                      — манифест, MainActivity,
                                 NativeAudioHelper (EQ+теги),
                                 ScreenRecordService (MediaProjection)
```

## Как собрать и запустить

Требуется **Flutter SDK** с поддержкой Android и Windows.

### 1. Сгенерировать платформенные оболочки (один раз)

Уже созданы `lib/`, `pubspec.yaml` и частично `android/`. Достройте стандартный
каркас из корня проекта:

```bash
flutter create --platforms=android,windows --org com.shubka --project-name pleer .
```

> Существующие файлы `lib/` и `android/src` сохранятся, будут добавлены
> недостающие (Gradle, Windows runner, иконки…).

### 2. Зависимости и кодогенерация

```bash
flutter pub get
flutter pub run build_runner build   # Hive-адаптеры (models.g.dart)
```

### 3. Запуск / сборка

```bash
flutter run -d android        # устройство/эмулятор
flutter run -d windows        # Windows desktop
flutter build apk --release
flutter build windows --release
```

## Права (Android)

В манифесте объявлены: `READ_MEDIA_AUDIO`, `READ_MEDIA_VIDEO`,
`READ_EXTERNAL_STORAGE` (≤ API 32), `RECORD_AUDIO`, `CAMERA`,
`FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`,
`POST_NOTIFICATIONS`, `WAKE_LOCK`, `MODIFY_AUDIO_SETTINGS`.

- Разрешения на чтение медиа запрашиваются в рантайме через `on_audio_query`.
- Запись звука/камеры — рантайм-запросы пакетов `record`/`camera`.
- Запись экрана использует системный диалог MediaProjection (Android 10+),
  приложения запуск через фоновый сервис.

## Известные ограничения
- Нативный эквалайзер работает только на Android (Windows — пресеты громкости).
- Запись ID3 — заглушка (безопасно; для записи нужна библиотека mp3agic/jaudiotagger).
- PiP подключается для видеоплеера; аудио работает в фоне без PiP.

— Pleer