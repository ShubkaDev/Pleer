import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/design.dart';
import '../services/screen_recorder_controller.dart';

class ScreenRecorderScreen extends StatelessWidget {
  const ScreenRecorderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScreenRecorderController(),
      child: const _ScreenRecorderBody(),
    );
  }
}

class _ScreenRecorderBody extends StatefulWidget {
  const _ScreenRecorderBody();

  @override
  State<_ScreenRecorderBody> createState() => _ScreenRecorderBodyState();
}

class _ScreenRecorderBodyState extends State<_ScreenRecorderBody>
    with WidgetsBindingObserver {
  bool _overlayGranted = false;
  bool _checkingOverlay = true;

  ScreenRecorderController? _ctrl;
  String? _shownPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOverlay();
      final ctrl = context.read<ScreenRecorderController>();
      _ctrl = ctrl;
      ctrl.addListener(_onCtrlChanged);
    });
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onCtrlChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onCtrlChanged() {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    final path = ctrl.lastSavedPath;
    if (path == null || path.isEmpty || path == _shownPath) return;
    _shownPath = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Видео сохранено — откройте раздел «Видео»'),
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOverlay();
  }

  Future<void> _refreshOverlay() async {
    if (!mounted) return;
    final ctrl = context.read<ScreenRecorderController>();
    final granted = await ctrl.canDrawOverlays();
    if (!mounted) return;
    setState(() {
      _overlayGranted = granted;
      _checkingOverlay = false;
    });
  }

  Future<void> _askOverlay() async {
    final ctrl = context.read<ScreenRecorderController>();
    await ctrl.requestOverlayPermission();
    await _refreshOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ScreenRecorderController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Запись экрана')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 12),
          Center(
            child: ctrl.isRecording
                ? const _PulseDot()
                : Icon(Icons.screen_share, color: scheme.primary, size: 72),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              ctrl.isRecording
                  ? 'Идёт запись… ${_fmt(ctrl.duration)}'
                  : 'Запишите происходящее на экране',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (ctrl.isRecording)
            Center(
              child: Text(
                ctrl.bubbleVisible
                    ? 'Кружок на экране: тап — остановить, перетаскивание — переместить'
                    : 'Кружок не виден: нет разрешения «Поверх других приложений».\n'
                        'Остановить можно кнопкой «Стоп» в уведомлении.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          if (ctrl.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: PleerDesign.brLg,
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ctrl.error!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: ctrl.isRecording ? ctrl.stop : () => _start(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctrl.isRecording ? Colors.red : scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: Icon(
                ctrl.isRecording ? Icons.stop : Icons.radio_button_checked),
            label: Text(
              ctrl.isRecording ? 'Остановить' : 'Начать запись',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 20),
          if (!_checkingOverlay)
            _PermissionCard(
              granted: _overlayGranted,
              onGrant: _askOverlay,
            ),
          if (!ctrl.isSupported)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Запись экрана доступна только на Android',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Записанное видео сохраняется в Movies/Pleer и появляется в разделе «Видео».',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext ctx) async {
    final ctrl = ctx.read<ScreenRecorderController>();
    final overlayGranted = await ctrl.canDrawOverlays();
    if (!overlayGranted) {
      if (ctx.mounted) {
        await _askOverlay();
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Разрешите «Поверх других приложений», чтобы видеть кружок '
                'остановки записи, и нажмите «Начать запись» ещё раз.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
      return;
    }
    try {
      await ctrl.start();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.granted, required this.onGrant});

  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final color = granted ? Colors.greenAccent : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: PleerDesign.brLg,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(granted ? Icons.check_circle : Icons.layers_outlined,
              color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  granted
                      ? 'Кружок остановки включён'
                      : 'Нужно право «Поверх других приложений»',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  granted
                      ? 'Во время записи на экране будет плавающий кружок.'
                      : 'Без него не получится показать кнопку остановки поверх других приложений.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: onGrant,
              child: const Text('Разрешить'),
            ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 72),
    );
  }
}
