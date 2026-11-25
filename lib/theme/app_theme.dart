import 'package:flutter/material.dart';

abstract final class AppColors {
  static bool darkMode = false;

  static Color get ink =>
      darkMode ? const Color(0xFFE7ECF4) : const Color(0xFF172235);
  static Color get muted =>
      darkMode ? const Color(0xFFA0AEC0) : const Color(0xFF76817D);
  static Color get navy =>
      darkMode ? const Color(0xFF91B5F0) : const Color(0xFF203D6B);
  static Color get navyDark =>
      darkMode ? const Color(0xFFD7E4F8) : const Color(0xFF14294B);
  static Color get page =>
      darkMode ? const Color(0xFF192A3E) : const Color(0xFFF4F6FA);
  static Color get line =>
      darkMode ? const Color(0xFF405775) : const Color(0xFFE4E8EF);
  static Color get paper =>
      darkMode ? const Color(0xFF263B54) : const Color(0xFFFFFFFF);
}

abstract final class AppTheme {
  static ThemeData get light => _build(dark: false);
  static ThemeData get dark => _build(dark: true);

  static ThemeData _build({required bool dark}) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    final ink = dark ? const Color(0xFFE7ECF4) : const Color(0xFF172235);
    final muted = dark ? const Color(0xFFA0AEC0) : const Color(0xFF76817D);
    final primary = dark ? const Color(0xFF91B5F0) : const Color(0xFF203D6B);
    final page = dark ? const Color(0xFF192A3E) : const Color(0xFFF4F6FA);
    final line = dark ? const Color(0xFF405775) : const Color(0xFFE4E8EF);
    final paper = dark ? const Color(0xFF263B54) : const Color(0xFFFFFFFF);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: dark ? const Color(0xFF10213A) : Colors.white,
          surface: paper,
          onSurface: ink,
          error: dark ? const Color(0xFFFFB4A9) : const Color(0xFFA3443A),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: page,
      cardColor: paper,
      dividerColor: line,
      dialogTheme: DialogThemeData(backgroundColor: paper),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: primary.withValues(alpha: dark ? .24 : .12),
      ),
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(color: muted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: dark ? const Color(0xFFFFB4A9) : const Color(0xFFA3443A),
          ),
        ),
      ),
    );
  }
}
