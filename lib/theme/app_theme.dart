import 'package:flutter/material.dart';

import 'design.dart';

class AppTheme {
  static const _seed = Color(0xFF6C4CF1);

  static ThemeData lightTheme({bool dynamicColor = false}) =>
      _base(Brightness.light, dynamicColor: dynamicColor);
  static ThemeData darkTheme({bool dynamicColor = false}) =>
      _base(Brightness.dark, dynamicColor: dynamicColor);

  static ThemeData _base(Brightness brightness, {bool dynamicColor = false}) {
    final isLight = brightness == Brightness.light;
    final ColorScheme scheme;
    if (dynamicColor) {
      // Акцентная схема в стиле Material You: вариация от базового сине-фиолетового.
      scheme = ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.content,
      );
    } else {
      scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isLight ? PleerDesign.lightBg : PleerDesign.darkBg,
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : PleerDesign.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: PleerDesign.brMd,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : Colors.grey,
          );
        }),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: PleerDesign.brMd),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: PleerDesign.brSm),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}