// lib/screens/ai_insights_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/colors.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final _api = ApiService();

  // ── Weekly AI Insight ──────────────────────────────────────────────────────
  Map<String, dynamic>? _insight;
  bool _insightLoading = false;
  String? _insightError;

  // ── Meal Correlation ───────────────────────────────────────────────────────
  List<dynamic> _correlations = [];
  bool _correlationLoading = false;
  String? _correlationError;

  // ── Monthly Report ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _report;
  bool _reportLoading = false;
  String? _reportError;

  @override
  void initState() {
    super.initState();
    _fetchInsight();
    _fetchCorrelation();
  }

  // ── Fetch helpers ──────────────────────────────────────────────────────────

  Future<void> _fetchInsight() async {
    setState(() {
      _insightLoading = true;
      _insightError = null;
    });
    try {
      final data = await _api.getAiInsights(days: 7);
      if (mounted) setState(() => _insight = data);
    } catch (e) {
      if (mounted) setState(() => _insightError = e.toString());
    } finally {
      if (mounted) setState(() => _insightLoading = false);
    }
  }

  Future<void> _fetchCorrelation() async {
    setState(() {
      _correlationLoading = true;
      _correlationError = null;
    });
    try {
      final data = await _api.getMealCorrelation();
      if (mounted) setState(() => _correlations = data);
    } catch (e) {
      if (mounted) setState(() => _correlationError = e.toString());
    } finally {
      if (mounted) setState(() => _correlationLoading = false);
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _reportLoading = true;
      _reportError = null;
      _report = null;
    });
    try {
      final data = await _api.getMonthlyReport(days: 30);
      if (mounted) setState(() => _report = data);
    } catch (e) {
      if (mounted) setState(() => _reportError = e.toString());
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _insight = null;
      _correlations = [];
      _report = null;
      _reportError = null;
    });
    await Future.wait([_fetchInsight(), _fetchCorrelation()]);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Insights & Reports',
          style: GoogleFonts.splineSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceSolid,
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _buildSectionLabel('Weekly AI Insight'),
            const SizedBox(height: 10),
            _buildInsightCard(),
            const SizedBox(height: 28),

            _buildSectionLabel('Meal Correlation'),
            const SizedBox(height: 10),
            _buildCorrelationSection(),
            const SizedBox(height: 28),

            _buildSectionLabel('Monthly Report'),
            const SizedBox(height: 10),
            _buildMonthlyReportCard(),

            const SizedBox(height: 20),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.splineSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textDim,
        letterSpacing: 1.1,
      ),
    );
  }

  // ── Weekly AI Insight card ─────────────────────────────────────────────────

  Widget _buildInsightCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Weekly Analysis',
                  style: GoogleFonts.splineSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              if (_insight?['cached'] == true)
                _badgePill('Cached', AppColors.primaryDim, AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          if (_insightLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_insightError != null)
            _inlineError(onRetry: _fetchInsight)
          else if (_insight != null) ...[
            Text(
              _insight!['insight'] as String? ?? '',
              style: GoogleFonts.splineSans(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.65,
              ),
            ),
            if (_insight!['generated_at'] != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatGeneratedAt(_insight!['generated_at'] as String),
                    style: GoogleFonts.splineSans(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No insight available yet.',
                  style: GoogleFonts.splineSans(
                    fontSize: 13,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Meal Correlation section ───────────────────────────────────────────────

  Widget _buildCorrelationSection() {
    if (_correlationLoading) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_correlationError != null) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: _inlineError(onRetry: _fetchCorrelation),
      );
    }

    if (_correlations.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No meal correlation data yet.',
            style: GoogleFonts.splineSans(
              fontSize: 13,
              color: AppColors.textDim,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _correlations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = _correlations[i] as Map<String, dynamic>;
          return _buildCorrelationCard(item);
        },
      ),
    );
  }

  Widget _buildCorrelationCard(Map<String, dynamic> item) {
    final mealType = item['meal_type'] as String? ?? 'Unknown';
    final avgGlucose = (item['avg_glucose_after'] as num?)?.toDouble() ?? 0.0;
    final spike = (item['spike'] as num?)?.toDouble() ?? 0.0;

    final spikeColor = spike > 50
        ? AppColors.high
        : spike > 25
        ? AppColors.accentCoral
        : AppColors.inRange;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatMealType(mealType),
              style: GoogleFonts.splineSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${avgGlucose.toStringAsFixed(0)} mg/dL',
              style: GoogleFonts.splineSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'avg after meal',
              style: GoogleFonts.splineSans(
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 10),
            _badgePill(
              '+${spike.toStringAsFixed(0)} spike',
              spikeColor.withValues(alpha: 0.18),
              spikeColor,
            ),
          ],
        ),
      ),
    );
  }

  // ── Monthly Report card ────────────────────────────────────────────────────

  Widget _buildMonthlyReportCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentCoral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 20,
                  color: AppColors.accentCoral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Report',
                      style: GoogleFonts.splineSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    Text(
                      'Last 30 days · PDF',
                      style: GoogleFonts.splineSans(
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_reportError != null) ...[
            _inlineError(onRetry: _generateReport),
            const SizedBox(height: 16),
          ],

          if (_report != null && _reportError == null) ...[
            _buildPdfLink(_report!),
            const SizedBox(height: 16),
          ],

          PrimaryButton(
            label: _report != null ? 'Regenerate Report' : 'Generate Report',
            icon: Icons.picture_as_pdf_rounded,
            loading: _reportLoading,
            color: AppColors.accentCoral,
            onPressed: _generateReport,
          ),
        ],
      ),
    );
  }

  Widget _buildPdfLink(Map<String, dynamic> report) {
    final pdfUrl = report['pdf_url'] as String? ?? '';
    final reportDate = report['report_date'] as String? ?? '';

    if (pdfUrl.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openUrl(pdfUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report ready',
                    style: GoogleFonts.splineSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (reportDate.isNotEmpty)
                    Text(
                      reportDate,
                      style: GoogleFonts.splineSans(
                        fontSize: 11,
                        color: AppColors.textDim,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              'Open PDF',
              style: GoogleFonts.splineSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _inlineError({required VoidCallback onRetry}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.low, size: 32),
        const SizedBox(height: 8),
        Text(
          'Failed to load data',
          style: GoogleFonts.splineSans(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(
            Icons.refresh_rounded,
            size: 15,
            color: AppColors.primary,
          ),
          label: Text(
            'Retry',
            style: GoogleFonts.splineSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _badgePill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.splineSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'Not medical advice. Always consult your healthcare provider before making changes to your treatment plan.',
        textAlign: TextAlign.center,
        style: GoogleFonts.splineSans(
          fontSize: 11,
          color: AppColors.textDim,
          height: 1.5,
        ),
      ),
    );
  }

  String _formatGeneratedAt(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
    } catch (_) {
      return raw;
    }
  }

  String _formatMealType(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
