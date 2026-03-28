// lib/screens/log_bolus_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/colors.dart';
import '../services/juggluco_service.dart';
import '../services/offline_cache_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class LogBolusScreen extends StatefulWidget {
  const LogBolusScreen({super.key});

  @override
  State<LogBolusScreen> createState() => _LogBolusScreenState();
}

class _LogBolusScreenState extends State<LogBolusScreen> {
  final _cache = OfflineCacheService();
  final _juggluco = JugglucoService();
  final _profile = UserProfileService();

  double _units = 4.5;
  String _bolusType = 'meal';
  String _mealType = 'medium_gi';
  final _glucoseController = TextEditingController();
  final _notesController = TextEditingController();
  double? _glucoseAtInjection;
  bool _saving = false;
  bool _fetchingGlucose = false;

  DateTime _loggedAt = DateTime.now();

  List<Map<String, dynamic>> _todayBoluses = [];
  double _todayTotal = 0;

  final List<String> _bolusTypes = ['manual', 'meal', 'correction'];
  final List<String> _bolusTypeLabels = ['Manual', 'Meal', 'Correction'];
  final List<Map<String, String>> _mealTypes = [
    {'value': 'low_gi', 'label': 'Low GI'},
    {'value': 'medium_gi', 'label': 'Medium GI'},
    {'value': 'high_gi', 'label': 'High GI'},
  ];

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
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadDailyLog();
    _fetchCurrentGlucose();
  }

  @override
  void dispose() {
    _glucoseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadDailyLog() {
    setState(() {
      _todayBoluses = _cache.getTodayBoluses();
      _todayTotal = _cache.getTodayTotalBolus();
    });
  }

  Future<void> _fetchCurrentGlucose() async {
    if (!_profile.jugglucoEnabled) return;
    setState(() => _fetchingGlucose = true);
    try {
      final reading = await _juggluco.fetchCurrent();
      if (mounted && reading != null) {
        setState(() {
          _glucoseAtInjection = reading.value;
          _glucoseController.text = reading.value.toStringAsFixed(0);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _fetchingGlucose = false);
  }

  Future<void> _fetchGlucoseAtTime(DateTime time) async {
    if (!_profile.jugglucoEnabled) return;
    setState(() => _fetchingGlucose = true);
    try {
      final reading = await _juggluco.fetchAtTime(time);
      if (mounted && reading != null) {
        setState(() {
          _glucoseAtInjection = reading.value;
          _glucoseController.text = reading.value.toStringAsFixed(0);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _fetchingGlucose = false);
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      builder: (context, child) => _darkDatePickerTheme(child),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
      builder: (context, child) => _darkDatePickerTheme(child),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _loggedAt = picked);
    await _fetchGlucoseAtTime(picked);
  }

  Widget _darkDatePickerTheme(Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
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
    final glucoseText = _glucoseController.text.trim();
    if (glucoseText.isNotEmpty) {
      _glucoseAtInjection = double.tryParse(glucoseText);
    }
    setState(() => _saving = true);
    try {
      await _cache.logBolus(
        units: _units,
        bolusType: _bolusType,
        mealType: _bolusType == 'meal' ? _mealType : null,
        glucoseAtInjection: _glucoseAtInjection,
        notes: _notesController.text,
        loggedAt: _loggedAt,
      );
      if (mounted) {
        _showSnack(
          'Bolus logged: ${_units.toStringAsFixed(1)} units',
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
          'Log Bolus',
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
            if (_todayBoluses.isNotEmpty) const SizedBox(height: 20),
            _buildTimePicker(),
            const SizedBox(height: 20),
            _buildGlucoseField(),
            const SizedBox(height: 20),
            _buildUnitsSlider(),
            const SizedBox(height: 20),
            _buildPillSection(
              label: 'Bolus Type',
              options: _bolusTypes,
              labels: _bolusTypeLabels,
              selected: _bolusType,
              accentColor: AppColors.accentCoral,
              onSelect: (v) => setState(() => _bolusType = v),
            ),
            if (_bolusType == 'meal') ...[
              const SizedBox(height: 20),
              _buildPillSection(
                label: 'Meal Type',
                options: _mealTypes.map((m) => m['value']!).toList(),
                labels: _mealTypes.map((m) => m['label']!).toList(),
                selected: _mealType,
                accentColor: AppColors.primary,
                onSelect: (v) => setState(() => _mealType = v),
              ),
            ],
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
              label: 'Save Bolus',
              onPressed: _save,
              loading: _saving,
              color: AppColors.accentCoral,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLogPanel() {
    if (_todayBoluses.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Boluses",
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentCoral,
                ),
              ),
              Text(
                '${_todayTotal.toStringAsFixed(1)} u total',
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCoral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._todayBoluses.map((b) {
            final t = DateFormat(
              'HH:mm',
            ).format(DateTime.parse(b['time'] as String));
            final units = (b['units'] as num).toStringAsFixed(1);
            final type = (b['type'] ?? '').toString();
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
                    type,
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
              color: isNow ? AppColors.borderGlass : AppColors.accentCoral,
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
                        color: AppColors.accentCoral,
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

  Widget _buildGlucoseField() {
    return _buildLabeledField(
      label: 'Glucose at Injection (mg/dL)',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _glucoseController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.splineSans(
                fontSize: 14,
                color: AppColors.textMain,
              ),
              decoration: _darkInputDecoration('e.g. 120 (optional)'),
            ),
          ),
          if (_profile.jugglucoEnabled) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _fetchGlucoseAtTime(_loggedAt),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGlass),
                ),
                child: _fetchingGlucose
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
              ),
            ),
          ],
        ],
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
                '${_units.toStringAsFixed(1)} u',
                style: GoogleFonts.splineSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCoral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accentCoral,
              inactiveTrackColor: AppColors.accentCoral.withValues(alpha: 0.2),
              thumbColor: AppColors.accentCoral,
              overlayColor: AppColors.accentCoral.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: _units,
              min: 0,
              max: 30,
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
                '30 u',
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

  Widget _buildPillSection({
    required String label,
    required List<String> options,
    required List<String> labels,
    required String selected,
    required Color accentColor,
    required ValueChanged<String> onSelect,
  }) {
    return _buildLabeledField(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(options.length, (i) {
          final isSelected = options[i] == selected;
          return GestureDetector(
            onTap: () => onSelect(options[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? accentColor : AppColors.borderGlass,
                ),
              ),
              child: Text(
                labels[i],
                style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        }),
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
