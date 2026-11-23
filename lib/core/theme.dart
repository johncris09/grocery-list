import 'package:flutter/material.dart';

/// Colors and type taken from the approved "Grocery List" design canvas.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF4F3EE); // header band
  static const surface = Color(0xFFFFFFFF); // sheet
  static const ink = Color(0xFF1E1E1C);
  static const muted = Color(0xFF6B6A65);
  static const accent = Color(0xFF2E6B4F);
  static const accentDark = Color(0xFF1F4D38);
  static const accentSoft = Color(0xFFE3EFE8); // history tick bubble
  static const divider = Color(0xFFE6E4DD);
  static const inputBorder = Color(0xFFD6D3CA);
  static const tabTrack = Color(0xFFEDECE6);
  static const doneText = Color(0xFF8A8880);
  static const doneQty = Color(0xFFA3A199);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surface,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : Colors.transparent,
      ),
      side: const BorderSide(color: AppColors.muted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
