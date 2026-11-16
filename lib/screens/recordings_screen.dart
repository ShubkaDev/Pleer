import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design.dart';
import 'audio_recorder_screen.dart';
import 'screen_recorder_screen.dart';

const MethodChannel _cameraChannel = MethodChannel('multitool.camera');

/// Экран-хаб инструментов записи.
class RecordingsScreen extends StatelessWidget {
  const RecordingsScreen({super.key});

  Future<void> _openCamera(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _cameraChannel.invokeMethod('launch');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть камеру')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Инструменты записи')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          _CameraCard(onTap: () => _openCamera(context)),
          const SizedBox(height: 14),
          _ToolCard(
            icon: Icons.mic_none_rounded,
            title: 'Запись звука',
            subtitle: 'Сохраняй мысли, лекции и музыку',
            color: scheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioRecorderScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.screen_share_outlined,
            title: 'Запись экрана',
            subtitle: 'Делитесь тем, что на дисплее',
            color: Colors.deepPurpleAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScreenRecorderScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Крупная карточка камеры: сразу видно, что здесь можно снимать видео.
class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: PleerDesign.brLg,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8465C), Color(0xFF8B3BE8)],
          ),
          borderRadius: PleerDesign.brLg,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8465C).withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Снять видео',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Камера откроется в приложении, файл сохранится в «Видео»',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: PleerDesign.brMd,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: PleerDesign.brMd,
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}
