import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

enum GlucoseStatus { inRange, high, low }

class BadgeChip extends StatelessWidget {
  final String label;
  final GlucoseStatus status;

  const BadgeChip({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case GlucoseStatus.inRange:
        bg = AppColors.accentGreenLight;
        fg = AppColors.accentGreen;
        break;
      case GlucoseStatus.high:
        bg = AppColors.highBg;
        fg = AppColors.accentWarning;
        break;
      case GlucoseStatus.low:
        bg = AppColors.lowHypoBg;
        fg = AppColors.accentRed;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
