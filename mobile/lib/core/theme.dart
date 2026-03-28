import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static TextTheme get _textTheme => GoogleFonts.splineSansTextTheme(
        const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textMain),
          bodySmall: TextStyle(color: AppColors.textMuted),
        ),
      );

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accentCoral,
        surface: AppColors.surfaceSolid,
        error: AppColors.low,
      ),
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.splineSans(
          color: AppColors.textMain,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceGlass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderGlass),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderGlass),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.splineSans(
            color: AppColors.textDim, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.splineSans(
              fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: GoogleFonts.splineSans(color: AppColors.textMain),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Glass card decoration — used in widgets
  static BoxDecoration glassDecoration({
    double radius = 16,
    Color? border,
  }) =>
      BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: border ?? AppColors.borderGlass, width: 1),
      );

  // Solid surface card
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGlass),
      );

  // Legacy alias
  static BoxDecoration get subtleCardDecoration => cardDecoration;
}
