import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/player_controller.dart';

/// Строка управления сортировкой аудио: выбор поля и направление.
/// Используется на главном экране и в библиотеке.
class SortControls extends StatelessWidget {
  const SortControls({super.key, this.compact = false});

  final bool compact;

  static String label(SortMode mode) {
    switch (mode) {
      case SortMode.title:
        return 'По названию';
      case SortMode.dateAdded:
        return 'По дате создания';
    }
  }

  static IconData icon(SortMode mode) {
    switch (mode) {
      case SortMode.title:
        return Icons.sort_by_alpha;
      case SortMode.dateAdded:
        return Icons.date_range;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 0 : 2,
      ),
      child: Row(
        children: [
          PopupMenuButton<SortMode>(
            tooltip: 'Сортировка',
            initialValue: ctrl.sortMode,
            onSelected: ctrl.setSortMode,
            itemBuilder: (ctx) => [
              for (final mode in SortMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(icon(mode), size: 18),
                      const SizedBox(width: 10),
                      Text(label(mode)),
                      if (mode == ctrl.sortMode) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 18),
                      ],
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    label(ctrl.sortMode),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: ctrl.sortAscending ? 'По возрастанию' : 'По убыванию',
            icon: Icon(
              ctrl.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
            ),
            onPressed: () => ctrl.setSortAscending(!ctrl.sortAscending),
          ),
        ],
      ),
    );
  }
}
