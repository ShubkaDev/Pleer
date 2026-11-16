import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/player_controller.dart';
import '../services/equalizer_helper.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final isAndroid = EqualizerHelper().isSupported;

    return Scaffold(
      appBar: AppBar(title: const Text('Эквалайзер')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isAndroid)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Аппаратный эквалайзер доступен только на Android. '
                        'На Windows пресеты применяются как частотная коррекция '
                        'громкости.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Эквалайзер', style: TextStyle(fontSize: 16)),
              Switch(
                value: ctrl.eqEnabled,
                onChanged: ctrl.setEqEnabled,
              ),
            ],
          ),
          DropdownButton<String>(
            value: ctrl.eqPreset,
            isExpanded: true,
            items: [
              for (final p in PlayerController.presets)
                DropdownMenuItem(value: p, child: Text(p)),
              for (final p in ctrl.customPresetNames)
                DropdownMenuItem(value: p, child: Text('⭐ $p')),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (ctrl.customPresetNames.contains(v)) {
                ctrl.applyCustomPreset(v);
              } else {
                ctrl.applyEqPreset(v);
              }
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _saveCustomPreset(),
              icon: const Icon(Icons.save_alt),
              label: const Text('Сохранить пресет'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int b = 0; b < PlayerController.eqBands; b++)
                _BandSlider(band: b, gains: ctrl.eqGains, onChanged: ctrl.setEqBand),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          Row(
            children: [
              const Icon(Icons.graphic_eq),
              const SizedBox(width: 8),
              const Expanded(child: Text('Bass Boost', style: TextStyle(fontSize: 16))),
              Slider(
                value: _bassBoost(),
                min: 0,
                max: 100,
                onChanged: _applyBassBoost,
              ),
            ],
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Скорость воспроизведения'),
            subtitle: Text('${ctrl.playbackSpeed.toStringAsFixed(2)}x'),
            trailing: DropdownButton<double>(
              value: ctrl.playbackSpeed,
              items: [
                for (final s in [0.5, 0.75, 0.9, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0])
                  DropdownMenuItem(
                    value: s,
                    child: Text('${s.toStringAsFixed(2)}x'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) ctrl.setPlaybackSpeed(v);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bedtime),
            title: const Text('Таймер сна'),
            subtitle: Text(
              ctrl.sleepTimerActive
                  ? 'Отключится через ${ctrl.sleepTimeLeft.inMinutes} мин'
                  : 'Не активен',
            ),
            trailing: (ctrl.sleepTimerActive
                ? TextButton(
                    onPressed: ctrl.cancelSleepTimer,
                    child: const Text('Отменить'),
                  )
                : const SizedBox.shrink()),
            onTap: _showSleepDialog,
          ),
        ],
      ),
    );
  }

  double _bassBoost() {
    final gains = context.read<PlayerController>().eqGains;
    if (gains[0] <= 0) return 0;
    return (gains[0] * 15).clamp(0.0, 100.0);
  }

  void _applyBassBoost(double v) {
    final ctrl = context.read<PlayerController>();
    final gains = [...ctrl.eqGains];
    final diff = (v / 20) - gains[0];
    // перераспределяем между первыми двумя полосами как приближение bass boost
    gains[0] = (v / 15).clamp(PlayerController.eqMin, PlayerController.eqMax);
    // используем 5-полосный пресет Bass boost для сопоставления
    if (v > 0) {
      gains[1] = (gains[0] * 0.7).clamp(PlayerController.eqMin, PlayerController.eqMax);
    }
    for (int b = 0; b < gains.length; b++) {
      ctrl.setEqBand(b, gains[b]);
    }
  }

  void _showSleepDialog() {
    final ctrl = context.read<PlayerController>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final options = <String, Duration>{
          'Через 5 минут': const Duration(minutes: 5),
          'Через 15 минут': const Duration(minutes: 15),
          'Через 30 минут': const Duration(minutes: 30),
          'Через 1 час': const Duration(hours: 1),
          'Через 2 часа': const Duration(hours: 2),
          'До конца альбома': const Duration(days: 1), // заглушка
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Плавное затухание'),
                subtitle: const Text('Громкость плавно снизится перед выключением'),
                value: true,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  _showSleepDialog();
                },
              ),
              for (final e in options.entries)
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(e.key),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (e.key == 'До конца альбома') {
                      // до конца альбома = пауза по завершению трека
                      _scheduleToEndOfAlbum(ctx);
                    } else {
                      ctrl.startSleepTimer(e.value);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _scheduleToEndOfAlbum(BuildContext ctx) {}

  void _saveCustomPreset() {
    final ctrl = context.read<PlayerController>();
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить пресет'),
        content: TextField(
          controller: tc,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название пресета'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = tc.text.trim();
              if (name.isNotEmpty) {
                ctrl.saveCustomPreset(name, List.of(ctrl.eqGains));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _BandSliderLayout() => const SizedBox.shrink();
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.band,
    required this.gains,
    required this.onChanged,
  });

  final int band;
  final List<double> gains;
  final void Function(int, double) onChanged;

  static const _labels = ['60', '230', '910', '3.6k', '14k'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = band < gains.length ? gains[band] : 0.0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value > 0 ? '+${value.round()}' : '${value.round()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        RotatedBox(
          quarterTurns: 3,
          child: SizedBox(
            height: 120,
            child: Slider(
              value: value,
              min: PlayerController.eqMin,
              max: PlayerController.eqMax,
              onChanged: (v) => onChanged(band, v),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(_labels[band], style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}