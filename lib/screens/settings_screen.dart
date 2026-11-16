import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../logic/player_controller.dart';
import '../theme/design.dart';
import 'about_screen.dart';
import 'background_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          _Section(
            title: 'Оформление',
            children: [
              ListTile(
                leading: const Icon(Icons.wallpaper),
                title: const Text('Фон приложения'),
                subtitle: const Text('Градиент или картинка'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackgroundScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Тема'),
                trailing: DropdownButton<ThemeMode>(
                  value: ctrl.themeMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('Системная')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Светлая')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Тёмная')),
                  ],
                  onChanged: (m) {
                    if (m != null) ctrl.setThemeMode(m);
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.palette_outlined),
                title: const Text('Динамические цвета'),
                subtitle: const Text('Цвет из обоев (Android 12+)'),
                value: ctrl.dynamicColor,
                onChanged: ctrl.setDynamicColor,
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Язык'),
                trailing: DropdownButton<String>(
                  value: ctrl.locale.languageCode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ru', child: Text('Русский')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                  ],
                  onChanged: (code) {
                    if (code != null) ctrl.setLocale(Locale(code));
                  },
                ),
              ),
            ],
          ),
          _Section(
            title: 'Параметры воспроизведения',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Нормализация звука'),
                subtitle: const Text('Выравнивание громкости треков'),
                value: ctrl.normalize,
                onChanged: ctrl.setNormalize,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.shuffle),
                title: const Text('Случайный порядок'),
                value: ctrl.shuffle,
                onChanged: (_) => ctrl.toggleShuffle(),
              ),
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Скорость воспроизведения'),
                subtitle: Text('${ctrl.playbackSpeed.toStringAsFixed(2)}x'),
                onTap: () => _showSpeedPicker(context, ctrl),
              ),
            ],
          ),
          _Section(
            title: 'Расширенные настройки воспроизведения',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.skip_next),
                title: const Text('Автопереход к следующему'),
                subtitle: const Text('По завершении трека'),
                value: ctrl.autoNext,
                onChanged: ctrl.setAutoNext,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.replay_circle_filled_outlined),
                title: const Text('Продолжить с позиции'),
                subtitle: const Text('Память позиции (аудиокниги/подкасты)'),
                value: ctrl.resumeFromSavedPosition,
                onChanged: ctrl.setResumeFromSavedPosition,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.all_inclusive),
                title: const Text('Бесшовное воспроизведение'),
                subtitle: const Text('Gapless (без пауз между треками)'),
                value: ctrl.gapless,
                onChanged: ctrl.setGapless,
              ),
              ListTile(
                leading: const Icon(Icons.timelapse),
                title: const Text('Кроссфейд'),
                subtitle: Text(
                  ctrl.crossfadeMs == 0
                      ? 'Выключен'
                      : '${(ctrl.crossfadeMs / 1000).toStringAsFixed(1)} c',
                ),
                trailing: DropdownButton<int>(
                  value: ctrl.crossfadeMs,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Выкл')),
                    DropdownMenuItem(value: 2000, child: Text('2 c')),
                    DropdownMenuItem(value: 4000, child: Text('4 c')),
                    DropdownMenuItem(value: 6000, child: Text('6 c')),
                    DropdownMenuItem(value: 8000, child: Text('8 c')),
                  ],
                  onChanged: (v) {
                    if (v != null) ctrl.setCrossfade(v);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.skip_previous),
                title: const Text('Шаг перемотки'),
                trailing: DropdownButton<int>(
                  value: ctrl.seekStepSeconds,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 с')),
                    DropdownMenuItem(value: 10, child: Text('10 с')),
                    DropdownMenuItem(value: 15, child: Text('15 с')),
                    DropdownMenuItem(value: 30, child: Text('30 с')),
                  ],
                  onChanged: (v) {
                    if (v != null) ctrl.setSeekStep(v);
                  },
                ),
              ),
            ],
          ),
          _Section(
            title: 'О приложении',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('О приложении'),
                subtitle: Text(
                  'Pleer ${AboutScreen.appVersion} · Android + Windows',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSpeedPicker(BuildContext context, PlayerController ctrl) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in speeds)
                ListTile(
                  leading: Icon(
                    s == ctrl.playbackSpeed ? Icons.check_circle : Icons.radio_button_unchecked,
                  ),
                  title: Text('${s.toStringAsFixed(2)}x'),
                  onTap: () {
                    ctrl.setPlaybackSpeed(s);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: PleerDesign.brMd,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}