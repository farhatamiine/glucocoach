import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import 'badge_chip.dart';

class GlucoseCard extends StatelessWidget {
  final String value;
  final String time;
  final String tag;
  final GlucoseStatus status;
  final VoidCallback? onTap;

  const GlucoseCard({
    super.key,
    required this.value,
    required this.time,
    this.tag = '',
    this.status = GlucoseStatus.inRange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    switch (status) {
      case GlucoseStatus.inRange:
        dotColor = AppColors.accentGreen;
        break;
      case GlucoseStatus.high:
        dotColor = AppColors.accentWarning;
        break;
      case GlucoseStatus.low:
        dotColor = AppColors.accentRed;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          tag,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

