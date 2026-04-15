import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bgDeep = Color(0xFF0a0a14);
  static const bgSurface = Color(0xFF12121f);
  static const bgCard = Color(0xFF1a1a2e);
  static const bgCardHover = Color(0xFF222240);
  static const bgSidebar = Color(0xFF0e0e1a);
  static const red = Color(0xFFe63946);
  static const redGlow = Color(0x80e63946);
  static const redSoft = Color(0xFFff4d5a);
  static const redDark = Color(0xFFb82d38);
  static const white = Color(0xFFf0f0f5);
  static const whiteDim = Color(0xFFa0a0b8);
  static const whiteMuted = Color(0xFF6a6a80);
  static const gold = Color(0xFFffd166);
  static const green = Color(0xFF06d6a0);
  static const blue = Color(0xFF118ab2);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDeep,
      primaryColor: AppColors.red,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.red,
        secondary: AppColors.redSoft,
        surface: AppColors.bgSurface,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.w900),
          displayMedium: TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
          headlineLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.whiteDim, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: AppColors.white),
          bodyMedium: TextStyle(color: AppColors.whiteDim),
          bodySmall: TextStyle(color: AppColors.whiteMuted),
          labelLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          labelSmall: TextStyle(color: AppColors.whiteMuted),
        ),
      ),
      cardColor: AppColors.bgCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.whiteDim),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.whiteMuted, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.whiteMuted.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.whiteDim),
        hintStyle: const TextStyle(color: AppColors.whiteMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
