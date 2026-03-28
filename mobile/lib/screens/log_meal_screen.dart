// lib/screens/log_meal_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/api_service.dart';
import '../widgets/primary_button.dart';

class LogMealScreen extends StatefulWidget {
  const LogMealScreen({super.key});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _api = ApiService();

  String _mealType = 'medium_gi';
  final _carbsController = TextEditingController();
  final _descController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  static const List<_MealOption> _mealOptions = [
    _MealOption(
      value: 'low_gi',
      label: 'Low GI',
      subtitle: 'Slow-release carbs',
      icon: Icons.eco_rounded,
      color: AppColors.inRange,
    ),
    _MealOption(
      value: 'medium_gi',
      label: 'Medium GI',
      subtitle: 'Moderate impact',
      icon: Icons.grain_rounded,
      color: AppColors.high,
    ),
    _MealOption(
      value: 'high_gi',
      label: 'High GI',
      subtitle: 'Fast-acting carbs',
      icon: Icons.bolt_rounded,
      color: AppColors.low,
    ),
  ];

  InputDecoration _darkInputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.splineSans(
            color: AppColors.textDim, fontSize: 14),
        filled: true,
        fillColor: AppColors.surfaceGlass,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGlass),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGlass),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  @override
  void dispose() {
    _carbsController.dispose();
    _descController.dispose();
    _glucoseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final carbsText = _carbsController.text.trim();
    if (carbsText.isEmpty) {
      _showSnack('Please enter carb amount', AppColors.high);
      return;
    }
    final carbs = double.tryParse(carbsText);
    if (carbs == null || carbs < 0) {
      _showSnack('Enter a valid carb amount', AppColors.high);
      return;
    }

    final glucoseText = _glucoseController.text.trim();
    final glucoseBefore =
        glucoseText.isNotEmpty ? double.tryParse(glucoseText) : null;

    setState(() => _saving = true);
    try {
      await _api.logMeal(
        mealType: _mealType,
        carbs: carbs,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        glucoseBefore: glucoseBefore,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) {
        _showSnack('Meal logged successfully', AppColors.inRange);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppColors.low);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.splineSans(color: AppColors.textMain)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textMain, size: 20),
        ),
        title: Text(
          'Log Meal',
          style: GoogleFonts.splineSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Meal Type'),
            const SizedBox(height: 10),
            _buildMealTypeCards(),
            const SizedBox(height: 24),
            _buildLabeledField(
              label: 'Carbs (grams)',
              required: true,
              child: TextField(
                controller: _carbsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.splineSans(
                    fontSize: 14, color: AppColors.textMain),
                decoration: _darkInputDecoration('e.g. 45'),
              ),
            ),
            const SizedBox(height: 20),
            _buildLabeledField(
              label: 'Description',
              child: TextField(
                controller: _descController,
                style: GoogleFonts.splineSans(
                    fontSize: 14, color: AppColors.textMain),
                decoration:
                    _darkInputDecoration('e.g. Chicken rice bowl (optional)'),
              ),
            ),
            const SizedBox(height: 20),
            _buildLabeledField(
              label: 'Glucose Before (mg/dL)',
              child: TextField(
                controller: _glucoseController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.splineSans(
                    fontSize: 14, color: AppColors.textMain),
                decoration: _darkInputDecoration('e.g. 118 (optional)'),
              ),
            ),
            const SizedBox(height: 20),
            _buildLabeledField(
              label: 'Notes',
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                style: GoogleFonts.splineSans(
                    fontSize: 14, color: AppColors.textMain),
                decoration:
                    _darkInputDecoration('Add a note... (optional)'),
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Log Meal',
              onPressed: _submit,
              loading: _saving,
              color: AppColors.primary,
              icon: Icons.restaurant_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeCards() {
    return Row(
      children: _mealOptions.map((option) {
        final isSelected = option.value == _mealType;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _mealType = option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? option.color.withValues(alpha: 0.18)
                      : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? option.color
                        : AppColors.borderGlass,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: option.color.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(option.icon,
                              color: option.color, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(option.label,
                            style: GoogleFonts.splineSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? option.color
                                    : AppColors.textMain),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 3),
                        Text(option.subtitle,
                            style: GoogleFonts.splineSans(
                                fontSize: 10,
                                color: AppColors.textDim),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.splineSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted)),
            if (required)
              Text(' *',
                  style: GoogleFonts.splineSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.low)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: GoogleFonts.splineSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted));
  }
}

class _MealOption {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MealOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
