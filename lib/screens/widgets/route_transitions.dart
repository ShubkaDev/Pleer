import 'package:flutter/material.dart';

/// Маршрут «плеер открывается»: мягкий зум + подъём снизу + проявление.
/// Используется для открытия аудио-плеера и видеоплеера.
Route<T> playerRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(curved);
      final scale = Tween<double>(begin: 0.94, end: 1).animate(curved);
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.7, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
  );
}
