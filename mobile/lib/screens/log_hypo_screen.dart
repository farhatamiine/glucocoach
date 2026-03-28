import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/offline_cache_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class LogHypoScreen extends StatefulWidget {
  const LogHypoScreen({super.key});

  @override
  State<LogHypoScreen> createState() => _LogHypoScreenState();
}

class _LogHypoScreenState extends State<LogHypoScreen> {
  final _lowestCtrl = TextEditingController(text: '52');
  final _durationCtrl = TextEditingController(text: '25');
  final _notesCtrl = TextEditingController();
  DateTime _startedAt = DateTime.now();
  String _treatment = 'Juice';
  bool _saving = false;

  final _treatments = ['Juice', '3 sugar cubes', 'Glucose tablets', 'Other'];

  @override
  void dispose() {
    _lowestCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surfaceSolid,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startedAt = DateTime(
          _startedAt.year,
          _startedAt.month,
          _startedAt.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final lowest = double.tryParse(_lowestCtrl.text);
    if (lowest == null || lowest > 70) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lowest BG must be ≤ 70 mg/dL',
              style: GoogleFonts.splineSans()),
          backgroundColor: AppColors.low,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final duration = int.tryParse(_durationCtrl.text);
      await OfflineCacheService().logHypo(
        lowestValue: lowest,
        startedAt: _startedAt,
        durationMin: duration,
        treatedWith: _treatment,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hypo event logged',
              style: GoogleFonts.splineSans()),
          backgroundColor: AppColors.inRange,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.splineSans()),
          backgroundColor: AppColors.low,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Log Hypo Event',
            style: GoogleFonts.splineSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lowest BG
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lowest BG Reading',
                        style: GoogleFonts.splineSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lowestCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.splineSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppColors.low),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: '52',
                              hintStyle: GoogleFonts.splineSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDim),
                            ),
                          ),
                        ),
                        Text('mg/dL',
                            style: GoogleFonts.splineSans(
                                fontSize: 16, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Time picker
              GestureDetector(
                onTap: _pickTime,
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDim,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.access_time_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Started at',
                                style: GoogleFonts.splineSans(
                                    fontSize: 12,
                                    color: AppColors.textMuted)),
                            Text(
                                '${_startedAt.hour.toString().padLeft(2, '0')}:${_startedAt.minute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.splineSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMain)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textDim, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Duration
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duration (minutes)',
                        style: GoogleFonts.splineSans(
                            fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.splineSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: '25',
                        hintStyle: GoogleFonts.splineSans(
                            fontSize: 18, color: AppColors.textDim),
                        suffixText: 'min',
                        suffixStyle: GoogleFonts.splineSans(
                            color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Treatment
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treated with',
                        style: GoogleFonts.splineSans(
                            fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _treatments.map((t) {
                        final isSelected = _treatment == t;
                        return GestureDetector(
                          onTap: () => setState(() => _treatment = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.low.withValues(alpha: 0.2)
                                  : AppColors.surfaceGlass,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isSelected
                                      ? AppColors.low
                                      : AppColors.borderGlass),
                            ),
                            child: Text(t,
                                style: GoogleFonts.splineSans(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? AppColors.low
                                        : AppColors.textMuted)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Notes
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _notesCtrl,
                  style: GoogleFonts.splineSans(
                      fontSize: 14, color: AppColors.textMain),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)...',
                    hintStyle: GoogleFonts.splineSans(
                        fontSize: 14, color: AppColors.textDim),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Log Hypo Event',
                onPressed: _save,
                loading: _saving,
                color: AppColors.low,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
