import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.purpleDark,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.purpleLight,
      onPrimaryContainer: Color(0xFFECEAF8),
      secondary: AppColors.purple,
      onSecondary: AppColors.ink,
      secondaryContainer: Color(0xFF28272F),
      onSecondaryContainer: Color(0xFFF0EFF5),
      surface: AppColors.surface,
      onSurface: Color(0xFFF5F5F7),
      onSurfaceVariant: AppColors.gray,
      outline: AppColors.outline,
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Color(0xFFF5F5F7),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.purpleDark, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: AppColors.purpleDark,
      unselectedItemColor: AppColors.gray,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: false,
      showUnselectedLabels: false,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.purpleLight,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: AppColors.ink,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.purpleDark,
    ),
  );
}
