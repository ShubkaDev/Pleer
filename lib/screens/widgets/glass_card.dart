import 'package:flutter/material.dart';

import '../../theme/design.dart';

/// Полупрозрачная «стеклянная» панель — читаемость текста поверх градиента.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.padding = const EdgeInsets.all(4),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: PleerDesign.brMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: PleerDesign.brMd,
      onTap: onTap,
      child: content,
    );
  }
}