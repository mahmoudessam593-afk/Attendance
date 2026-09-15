import 'package:flutter/material.dart';

/// Brand colors sampled directly from assets/egypt_gas_logo.png (the
/// mountain mark's blue gradient and the flame/wordmark's green), so the
/// app's palette matches the company logo rather than an arbitrary blue.
class AppColors {
  AppColors._();

  static const Color brandBlue = Color(0xFF0C4890);
  static const Color brandBlueDark = Color(0xFF0A2F5C);
  static const Color brandBlueLight = Color(0xFF1F6FC4);
  static const Color brandGreen = Color(0xFF2FAE49);
  static const Color brandGreenLight = Color(0xFF7FCB4F);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: Brightness.light,
    ).copyWith(
      secondary: AppColors.brandGreen,
      tertiary: AppColors.brandGreenLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
