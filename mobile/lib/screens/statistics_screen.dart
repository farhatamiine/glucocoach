import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _api = ApiService();
  int _selectedPeriod = 0;
  final _periods = ['7 Days', '14 Days', '30 Days'];
  final _periodValues = ['7', '14', '30'];
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getGlucoseReport(days: _periodValues[_selectedPeriod]);
      setState(() { _report = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadReport,
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceSolid,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20,
                    MediaQuery.of(context).viewPadding.bottom + 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_error != null)
                      _buildError()
                    else ...[
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      _buildTirCard(),
                      const SizedBox(height: 16),
                      _buildVariabilityCard(),
                      const SizedBox(height: 16),
                      _buildPatternsCard(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistics',
              style: GoogleFonts.splineSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain)),
          const SizedBox(height: 16),
          // Period selector
          Row(
            children: List.generate(_periods.length, (i) {
              final isActive = _selectedPeriod == i;
              return Padding(
                padding: EdgeInsets.only(right: i < _periods.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedPeriod = i);
                    _loadReport();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.borderGlass),
                    ),
                    child: Text(_periods[i],
                        style: GoogleFonts.splineSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : AppColors.textMuted)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final stats = _report?['stats']?['stats'];
    final variability = _report?['variability'];
    final avg = stats?['average']?.toStringAsFixed(0) ?? '--';
    final gmi = stats?['gmi']?.toStringAsFixed(1) ?? '--';
    final min = variability?['lowest']?.toStringAsFixed(0) ?? '--';
    final max = variability?['highest']?.toStringAsFixed(0) ?? '--';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Average', value: avg, unit: 'mg/dL', color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Est. GMI', value: gmi, unit: '%', color: AppColors.inRange)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Minimum', value: min, unit: 'mg/dL', color: AppColors.low)),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Maximum', value: max, unit: 'mg/dL', color: AppColors.high)),
          ],
        ),
      ],
    );
  }

  Widget _buildTirCard() {
    final ranges = _report?['stats']?['ranges'];
    final tir = (ranges?['tir'] ?? 0.0).toDouble();
    final tar = (ranges?['tar'] ?? 0.0).toDouble();
    final tbr = (ranges?['tbr'] ?? 0.0).toDouble();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time in Range',
              style: GoogleFonts.splineSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain)),
          const SizedBox(height: 16),
          Row(
            children: [
              _TirCircle(pct: tir, color: AppColors.inRange, label: 'In Range'),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _TirRow(label: 'In Range (70–180)', pct: tir, color: AppColors.inRange),
                    const SizedBox(height: 8),
                    _TirRow(label: 'Above Range (>180)', pct: tar, color: AppColors.high),
                    const SizedBox(height: 8),
                    _TirRow(label: 'Below Range (<70)', pct: tbr, color: AppColors.low),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariabilityCard() {
    final v = _report?['variability'];
    if (v == null) return const SizedBox.shrink();
    final cv = (v['cv'] ?? 0).toStringAsFixed(1);
    final sd = (v['sd'] ?? 0).toStringAsFixed(1);
    final highest = (v['highest'] ?? 0).toStringAsFixed(0);
    final lowest = (v['lowest'] ?? 0).toStringAsFixed(0);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Variability',
              style: GoogleFonts.splineSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain)),
          const SizedBox(height: 14),
          Row(
            children: [
              _VariabilityItem(label: 'CV', value: '$cv%'),
              _VariabilityItem(label: 'Std Dev', value: '$sd mg/dL'),
              _VariabilityItem(label: 'Highest', value: '$highest mg/dL'),
              _VariabilityItem(label: 'Lowest', value: '$lowest mg/dL'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternsCard() {
    final patterns = _report?['patterns'];
    if (patterns == null) return const SizedBox.shrink();

    final periods = [
      ('Morning', patterns['morning']),
      ('Afternoon', patterns['afternoon']),
      ('Evening', patterns['evening']),
      ('Night', patterns['night']),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Patterns',
              style: GoogleFonts.splineSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain)),
          const SizedBox(height: 14),
          ...periods.map((p) {
            final data = p.$2;
            if (data == null) return const SizedBox.shrink();
            final avg = (data['avg'] ?? 0).toDouble();
            final Color c = avg > 180
                ? AppColors.high
                : avg < 70
                    ? AppColors.low
                    : AppColors.inRange;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.$1,
                        style: GoogleFonts.splineSans(
                            fontSize: 13, color: AppColors.textMuted)),
                  ),
                  Text('${avg.toStringAsFixed(0)} mg/dL  •  ${data['time'] ?? ''}',
                      style: GoogleFonts.splineSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.textDim, size: 40),
            const SizedBox(height: 12),
            Text('Could not load data',
                style: GoogleFonts.splineSans(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadReport,
              child: Text('Retry',
                  style: GoogleFonts.splineSans(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final String label, value, unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: GoogleFonts.splineSans(
                  fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.splineSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain)),
          Text(unit,
              style: GoogleFonts.splineSans(
                  fontSize: 10, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _TirCircle extends StatelessWidget {
  const _TirCircle(
      {required this.pct, required this.color, required this.label});
  final double pct;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text('${pct.toStringAsFixed(0)}%',
                  style: GoogleFonts.splineSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.splineSans(
                  fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TirRow extends StatelessWidget {
  const _TirRow(
      {required this.label, required this.pct, required this.color});
  final String label;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.splineSans(
                    fontSize: 11, color: AppColors.textMuted)),
            Text('${pct.toStringAsFixed(0)}%',
                style: GoogleFonts.splineSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _VariabilityItem extends StatelessWidget {
  const _VariabilityItem({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.splineSans(
                  fontSize: 10, color: AppColors.textDim)),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.splineSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
