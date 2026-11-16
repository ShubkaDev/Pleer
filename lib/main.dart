import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'data/models.dart';
import 'i18n/strings.dart';
import 'logic/player_controller.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/video_player_screen.dart';
import 'screens/widgets/app_background.dart';
import 'services/background_service.dart';
import 'services/favorites_store.dart';
import 'services/intent_media_service.dart';
import 'services/playlist_store.dart';
import 'theme/app_theme.dart';

/// Глобальный ключ навигатора — нужен, чтобы открывать файлы из проводника.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = PlayerController();

  // После перезагрузки телефона хранилище и фоновый сервис могут отвечать
  // медленно. Раньше любой зависший await не давал дойти до runApp — и экран
  // просто не появлялся. Теперь каждый шаг ограничен по времени.
  Future<void> guarded(
    String name,
    Future<void> Function() task, {
    Duration limit = const Duration(seconds: 6),
  }) async {
    try {
      await task().timeout(limit);
    } catch (e, st) {
      debugPrint('PLEER/start: "$name" failed: $e\n$st');
    }
  }

  await guarded('hive', () async {
    await Hive.initFlutter();
    try {
      Hive.registerAdapter(TrackAdapter());
    } catch (_) {}
    try {
      Hive.registerAdapter(PlaylistAdapter());
    } catch (_) {}
  });
  await guarded('playlists', () => PlaylistStore.instance.init());
  await guarded('favorites', () => FavoritesStore.instance.init());
  await guarded('history', () => HistoryStore.instance.init());
  await guarded('background', () => BackgroundService.instance.init());
  await guarded('controller', () => controller.init());
  await guarded('onboarding', () => controller.loadOnboarding(),
      limit: const Duration(seconds: 3));

  _setupExternalMedia(controller);

  runApp(MultiToolPlayerApp(controller: controller));
}

/// Обработка открытия файла из проводника (Android).
void _setupExternalMedia(PlayerController controller) {
  IntentMediaService.init((media) async {
    final uriStr = media['uri'] ?? '';
    if (uriStr.isEmpty) return;
    final type = media['type'] ?? '';
    final name = media['name'] ?? '';
    final uri = Uri.parse(uriStr);

    if (type.startsWith('video')) {
      final video = VideoItem(
        id: uriStr.hashCode,
        data: uriStr,
        title: name,
        album: '',
        artist: '',
        durationMs: 0,
        size: 0,
        dateAdded: 0,
      );
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(video: video, playlist: [video]),
        ),
      );
    } else {
      await controller.playExternal(uri, title: name);
    }
  });
}

class MultiToolPlayerApp extends StatefulWidget {
  const MultiToolPlayerApp({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<MultiToolPlayerApp> createState() => _MultiToolPlayerAppState();
}

class _MultiToolPlayerAppState extends State<MultiToolPlayerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // После блокировки экрана кнопкой питания Android иногда возвращает
    // приложение с пустым окном. Принудительный rebuild отдаёт новый кадр.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: Consumer<PlayerController>(
        builder: (context, ctrl, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'Pleer',
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              // Единый фирменный фон/градиент за всеми экранами.
              // Экраны используют прозрачные Scaffold, поэтому фон просвечивает везде.
              return AppBackground(child: child ?? const SizedBox.shrink());
            },
            theme: AppTheme.lightTheme(dynamicColor: ctrl.dynamicColor),
            darkTheme: AppTheme.darkTheme(dynamicColor: ctrl.dynamicColor),
            themeMode: ctrl.themeMode,
            locale: ctrl.locale,
            supportedLocales: PlayerController.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                final c = context.watch<PlayerController>();
                if (!c.onboardingAccepted) {
                  return OnboardingScreen(
                    onDone: () => c.acceptOnboarding(),
                  );
                }
                return const HomeScreen();
              },
            ),
          );
        },
      ),
    );
  }
}