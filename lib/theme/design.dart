import 'package:flutter/material.dart';

/// Единая дизайн-система Pleer: градиенты, цвета, радиусы, тени.
class PleerDesign {
  PleerDesign._();

  // Фирменный градиент (синий → фиолетовый → розовый)
  static const List<Color> brandColors = [
    Color(0xFF0F208D),
    Color(0xFF5716FF),
    Color(0xFFA62AFF),
    Color(0xFFE439B3),
  ];

  static const List<Color> brandColorsSoft = [
    Color(0xFF2B49D6),
    Color(0xFF7B45FF),
    Color(0xFFC15CFF),
    Color(0xFFF26BD0),
  ];

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brandColors,
  );

  static const LinearGradient brandGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brandColorsSoft,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF5716FF), Color(0xFFA62AFF), Color(0xFFE439B3)],
  );

  // Тёмные поверхности
  static const Color darkBg = Color(0xFF0B0B14);
  static const Color darkSurface = Color(0xFF16161F);
  static const Color darkSurfaceAlt = Color(0xFF1E1E2A);
  static const Color lightBg = Color(0xFFF6F5FB);

  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFA9A9BD);

  // Радиусы
  static const double rSm = 12;
  static const double rMd = 18;
  static const double rLg = 26;
  static const double rXl = 34;

  static BorderRadius get brSm => BorderRadius.circular(rSm);
  static BorderRadius get brMd => BorderRadius.circular(rMd);
  static BorderRadius get brLg => BorderRadius.circular(rLg);

  // Тени
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  );
}