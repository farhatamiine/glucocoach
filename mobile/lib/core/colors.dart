import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const bgDark = Color(0xFF1E2130);
  static const surfaceGlass = Color(0x42262B3D);
  static const surfaceSolid = Color(0xFF262B3D);
  static const surfaceElevated = Color(0xFF2D3348);

  // Primary accent
  static const primary = Color(0xFF00BFB3);
  static const primaryDim = Color(0x3300BFB3);

  // Semantic glucose colours
  static const inRange = Color(0xFF2ECC71);
  static const high = Color(0xFFF0A500);
  static const low = Color(0xFFFF6B6B);

  // Text
  static const textMain = Color(0xFFF8F9FA);
  static const textMuted = Color(0xFF9CA3AF);
  static const textDim = Color(0xFF6B7280);

  // Borders
  static const borderGlass = Color(0x14FFFFFF);
  static const borderSubtle = Color(0x1FFFFFFF);

  // Legacy aliases (kept so unchanged files still compile)
  static const bgPrimary = bgDark;
  static const bgCard = surfaceSolid;
  static const bgElevated = surfaceElevated;
  static const bgMuted = surfaceElevated;
  static const textPrimary = textMain;
  static const textSecondary = textMuted;
  static const textTertiary = textDim;
  static const textDisabled = Color(0xFF4B5563);
  static const accentGreen = primary;
  static const accentGreenDark = primary;
  static const accentGreenLight = primaryDim;
  static const accentCoral = Color(0xFFD89575);
  static const accentCoralLight = Color(0x33D89575);
  static const accentRed = low;
  static const lowHypoBg = Color(0x33FF6B6B);
  static const accentWarning = high;
  static const highBg = Color(0x33F0A500);
  static const navInactive = textDim;
  static const shadowColor = Color(0x28000000);
  static const shadowColorDark = Color(0x40000000);
  static const borderStrong = borderSubtle;
}
