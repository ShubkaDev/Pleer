import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/design.dart';

/// Экран «О приложении»: сведения о Pleer и о разработчике.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appVersion = '2.8.1 (281)';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: [
          _AppHeader(scheme: scheme),
          const SizedBox(height: 14),
          _Card(
            title: 'О приложении',
            child: Text(
              'Pleer — медиаплеер для Android и Windows: музыка и видео из '
              'локальной библиотеки, плейлисты и избранное, эквалайзер и '
              'регулировка скорости, а также запись звука, экрана и видео '
              'с камеры. Всё работает без рекламы и подписок.',
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 12),
          _DeveloperCard(),
          const SizedBox(height: 12),
          _LinksCard(),
        ],
      ),
    );
  }

  static TextStyle _bodyStyle(BuildContext context) => TextStyle(
        fontSize: 14.5,
        height: 1.45,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.82),
      );
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: PleerDesign.brandGradient,
            borderRadius: PleerDesign.brMd,
            boxShadow: PleerDesign.glow(PleerDesign.brandColors.last),
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pleer',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Универсальный медиа-центр',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Версия ${AboutScreen.appVersion}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: PleerDesign.brMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'РАЗРАБОТЧИК',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ShubkaDev',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) => Text(
              'ShubkaDev — автор Pleer и разработчик проекта. Pleer задуман как '
              'простой инструмент для повседневной работы с медиа: собрать '
              'музыку и видео с устройства в одну библиотеку, слушать и '
              'смотреть без лишнего, записывать звук, экран и видео с камеры. '
              'Проект развивается открыто — пожелания и замечания помогают '
              'делать приложение удобнее.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: PleerDesign.brMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          _linkTile(
            context,
            icon: Icons.code_rounded,
            label: 'GitHub: ShubkaDev',
            url: 'https://github.com/ShubkaDev',
            scheme: scheme,
          ),
          _linkTile(
            context,
            icon: Icons.play_circle_outline_rounded,
            label: 'YouTube: @shyb801_55',
            url: 'https://www.youtube.com/@shyb801_55',
            scheme: scheme,
          ),
          _linkTile(
            context,
            icon: Icons.folder_shared_outlined,
            label: 'GitFlic: ShubkaDev',
            url: 'https://gitflic.ru/user/shubkadev',
            scheme: scheme,
          ),
          _linkTile(
            context,
            icon: Icons.public_rounded,
            label: 'Сайт: shubka.page.gd',
            url: 'https://shubka.page.gd',
            scheme: scheme,
          ),
        ],
      ),
    );
  }

  Widget _linkTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
    required ColorScheme scheme,
  }) {
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      dense: true,
      title: Text(
        label,
        style: TextStyle(color: scheme.primary),
      ),
      trailing: const Icon(Icons.open_in_new_rounded, size: 16),
      onTap: () => _open(context, url),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: PleerDesign.brMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
