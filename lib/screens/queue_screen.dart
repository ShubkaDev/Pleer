import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/player_controller.dart';

/// Список текущей очереди воспроизведения.
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final queue = ctrl.queue;

    return Scaffold(
      appBar: AppBar(title: const Text('Очередь воспроизведения')),
      body: queue.isEmpty
          ? const Center(
              child: Text('Очередь пуста', style: TextStyle(color: Colors.grey)),
            )
          : ReorderableListView.builder(
              itemCount: queue.length,
              onReorder: (oldI, newI) {
                // перестановка в локальной очереди контроллера
                ctrl.reorderQueue(oldI, newI);
              },
              itemBuilder: (context, i) {
                final t = queue[i];
                final isCurrent = ctrl.currentId == t.id;
                return ListTile(
                  key: ValueKey('${t.id}_$i'),
                  leading: Icon(
                    isCurrent ? Icons.graphic_eq : Icons.music_note,
                    color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(
                    t.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  subtitle: Text(t.displayArtist, maxLines: 1),
                  trailing: i != ctrl.currentIndexFix
                      ? IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => ctrl.jumpToQueueIndex(i),
                        )
                      : IconButton(
                          icon: const Icon(Icons.highlight_off),
                          onPressed: () => ctrl.removeFromQueue(i),
                        ),
                  onTap: () => ctrl.jumpToQueueIndex(i),
                );
              },
            ),
    );
  }
}