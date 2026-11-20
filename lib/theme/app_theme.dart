import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF172235);
  static const muted = Color(0xFF76817D);
  static const navy = Color(0xFF203D6B);
  static const navyDark = Color(0xFF14294B);
  static const page = Color(0xFFF4F6FA);
  static const line = Color(0xFFE4E8EF);
  static const paper = Color(0xFFFFFFFF);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.navy,
          surface: AppColors.paper,
          error: const Color(0xFFA3443A),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.page,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9AA4B1), fontSize: 14),
        labelStyle: const TextStyle(color: Color(0xFF49534E), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFA3443A)),
        ),
      ),
    );
  }
}
