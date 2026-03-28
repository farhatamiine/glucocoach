// lib/screens/log_basal_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/colors.dart';
import '../services/offline_cache_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class LogBasalScreen extends StatefulWidget {
  const LogBasalScreen({super.key});

  @override
  State<LogBasalScreen> createState() => _LogBasalScreenState();
}

class _LogBasalScreenState extends State<LogBasalScreen> {
  final _cache = OfflineCacheService();

  double _units = 18;
  String _insulin = 'Glargine';
  String _timingLabel = 'Night';
  final _notesController = TextEditingController();
  bool _saving = false;

  DateTime _loggedAt = DateTime.now();

  List<Map<String, dynamic>> _todayBasals = [];
  double _todayTotal = 0;

  final List<String> _insulinTypes = ['Glargine', 'Degludec', 'Tresiba'];
  final List<String> _timingOptions = ['Night', 'Morning'];

  static const Color _basalAccent = Color(0xFF7B68EE);

  InputDecoration _darkInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.splineSans(color: AppColors.textDim, fontSize: 14),
    filled: true,
    fillColor: AppColors.surfaceGlass,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      borderSide: const BorderSide(color: _basalAccent, width: 1.5),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadDailyLog();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _loadDailyLog() {
    setState(() {
      _todayBasals = _cache.getTodayBasals();
      _todayTotal = _cache.getTodayTotalBasal();
    });
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      builder: (context, child) => _darkPickerTheme(child),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
      builder: (context, child) => _darkPickerTheme(child),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _loggedAt = picked;
      _timingLabel = picked.hour >= 18 || picked.hour < 6 ? 'Night' : 'Morning';
    });
  }

  Widget _darkPickerTheme(Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: _basalAccent,
          surface: AppColors.surfaceSolid,
          onSurface: AppColors.textMain,
        ),
        dialogTheme: DialogThemeData(backgroundColor: AppColors.surfaceSolid),
      ),
      child: child!,
    );
  }

  Future<void> _save() async {
    if (_units <= 0) {
      _showSnack('Units must be greater than 0', AppColors.low);
      return;
    }
    setState(() => _saving = true);
    try {
      await _cache.logBasal(
        units: _units,
        insulin: _insulin,
        time: _timingLabel,
        notes: _notesController.text,
        loggedAt: _loggedAt,
      );
      if (mounted) {
        _showSnack(
          'Basal logged: ${_units.round()} units of $_insulin',
          AppColors.inRange,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppColors.low);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.splineSans(color: AppColors.textMain),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textMain,
            size: 20,
          ),
        ),
        title: Text(
          'Log Basal',
          style: GoogleFonts.splineSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodayLogPanel(),
            if (_todayBasals.isNotEmpty) const SizedBox(height: 20),
            _buildTimePicker(),
            const SizedBox(height: 20),
            _buildInsulinPills(),
            const SizedBox(height: 20),
            _buildUnitsSlider(),
            const SizedBox(height: 20),
            _buildTimingPills(),
            const SizedBox(height: 20),
            _buildLabeledField(
              label: 'Notes',
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                style: GoogleFonts.splineSans(
                  fontSize: 14,
                  color: AppColors.textMain,
                ),
                decoration: _darkInputDecoration('Add a note... (optional)'),
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save Basal',
              onPressed: _save,
              loading: _saving,
              color: _basalAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLogPanel() {
    if (_todayBasals.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Basal",
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _basalAccent,
                ),
              ),
              Text(
                '${_todayTotal.toStringAsFixed(0)} u total',
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _basalAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._todayBasals.map((b) {
            final t = DateFormat(
              'HH:mm',
            ).format(DateTime.parse(b['time'] as String));
            final units = (b['units'] as num).toStringAsFixed(0);
            final insulin = (b['insulin'] ?? '').toString();
            final pending = b['pending'] == true;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Text(
                    t,
                    style: GoogleFonts.splineSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${units}u',
                    style: GoogleFonts.splineSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    insulin,
                    style: GoogleFonts.splineSans(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                  if (pending) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.high.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'pending sync',
                        style: GoogleFonts.splineSans(
                          fontSize: 10,
                          color: AppColors.high,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    final isNow = DateTime.now().difference(_loggedAt).inMinutes.abs() < 2;
    return _buildLabeledField(
      label: 'Logged at',
      child: GestureDetector(
        onTap: _pickTime,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNow ? AppColors.borderGlass : _basalAccent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNow
                        ? 'Now'
                        : DateFormat('HH:mm  \u2014  MMM d').format(_loggedAt),
                    style: GoogleFonts.splineSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMain,
                    ),
                  ),
                  if (!isNow)
                    Text(
                      'Logging missed injection',
                      style: GoogleFonts.splineSans(
                        fontSize: 11,
                        color: _basalAccent,
                      ),
                    ),
                ],
              ),
              const Icon(
                Icons.access_time_rounded,
                size: 18,
                color: AppColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsulinPills() {
    return _buildLabeledField(
      label: 'Insulin Type',
      child: Wrap(
        spacing: 8,
        children: _insulinTypes.map((type) {
          final isSelected = type == _insulin;
          return GestureDetector(
            onTap: () => setState(() => _insulin = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _basalAccent : AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _basalAccent : AppColors.borderGlass,
                ),
              ),
              child: Text(
                type,
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnitsSlider() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Units',
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '${_units.round()} u',
                style: GoogleFonts.splineSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _basalAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _basalAccent,
              inactiveTrackColor: _basalAccent.withValues(alpha: 0.2),
              thumbColor: _basalAccent,
              overlayColor: _basalAccent.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: _units,
              min: 0,
              max: 60,
              divisions: 60,
              onChanged: (v) => setState(() => _units = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 u',
                style: GoogleFonts.splineSans(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
              Text(
                '60 u',
                style: GoogleFonts.splineSans(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimingPills() {
    return _buildLabeledField(
      label: 'Injection Period',
      child: Row(
        children: _timingOptions.map((opt) {
          final isSelected = opt == _timingLabel;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _timingLabel = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? _basalAccent : AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _basalAccent : AppColors.borderGlass,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      opt,
                      style: GoogleFonts.splineSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.splineSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
