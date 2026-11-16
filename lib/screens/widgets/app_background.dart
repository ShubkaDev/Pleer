import 'package:flutter/material.dart';

import '../../services/background_service.dart';
import '../../theme/design.dart';

/// Фон приложения: градиент по умолчанию или выбранная картинка.
/// Под ним лежат экраны с прозрачным Scaffold, поэтому фон всегда виден.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = BackgroundService.instance.selected;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Базовый градиент (всегда под картинкой, как fallback).
        const DecoratedBox(
          decoration: BoxDecoration(gradient: PleerDesign.brandGradient),
        ),
        if (selected != null)
          Image.asset(
            selected,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        // Затемнение для читаемости текста поверх картинки.
        if (selected != null)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        child,
      ],
    );
  }
}