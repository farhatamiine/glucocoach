import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/colors.dart';

/// A frosted-glass card that matches the dark design system.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.border,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
                color: border ?? AppColors.borderGlass, width: 1),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
