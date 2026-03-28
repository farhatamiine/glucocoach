import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../screens/log_bolus_screen.dart';
import '../screens/log_basal_screen.dart';
import '../screens/log_meal_screen.dart';
import '../screens/log_hypo_screen.dart';

void showLogBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _LogBottomSheet(),
  );
}

class _LogBottomSheet extends StatelessWidget {
  const _LogBottomSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Log Entry',
            style: GoogleFonts.splineSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _LogTile(
                icon: Icons.water_drop_outlined,
                label: 'Bolus',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogBolusScreen()));
                },
              ),
              const SizedBox(width: 12),
              _LogTile(
                icon: Icons.medication_outlined,
                label: 'Basal',
                color: const Color(0xFF7C6AF7),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogBasalScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LogTile(
                icon: Icons.restaurant_outlined,
                label: 'Meal',
                color: AppColors.accentCoral,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogMealScreen()));
                },
              ),
              const SizedBox(width: 12),
              _LogTile(
                icon: Icons.warning_amber_rounded,
                label: 'Hypo',
                color: AppColors.low,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogHypoScreen()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
