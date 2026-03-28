import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../models/glucose_reading.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/juggluco_service.dart';
import '../widgets/glass_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  GlucoseReading? _glucoseReading;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _loadReport();
    JugglucoService().stream.listen((reading) {
      if (mounted) setState(() { _glucoseReading = reading; _lastUpdate = DateTime.now(); });
    });
    _fetchGlucoseNow();
  }

  Future<void> _fetchGlucoseNow() async {
    final reading = await JugglucoService().fetchCurrent();
    if (reading != null && mounted) {
      setState(() { _glucoseReading = reading; _lastUpdate = DateTime.now(); });
    }
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getGlucoseReport(days: '7');
      setState(() { _report = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
                    _buildGlucoseCard(),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_error != null)
                      _buildErrorCard()
                    else ...[
                      _buildTirCard(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      const SizedBox(height: 16),
                      _buildDawnCard(),
                      const SizedBox(height: 16),
                      _buildPatterns(),
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
    final name = AuthService().userName;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'U';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_greeting,',
                    style: GoogleFonts.splineSans(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(name,
                    style: GoogleFonts.splineSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain)),
              ],
            ),
          ),
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryDim,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: GoogleFonts.splineSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseCard() {
    final hasReading = _glucoseReading != null;
    final value = hasReading
        ? _glucoseReading!.value.toStringAsFixed(0)
        : '--';
    final trend = hasReading ? _glucoseReading!.trend : 'stable';

    Color statusColor;
    String statusLabel;
    if (!hasReading) {
      statusColor = AppColors.textDim;
      statusLabel = 'No Data';
    } else {
      final v = _glucoseReading!.value;
      if (v < 70) {
        statusColor = AppColors.low;
        statusLabel = 'Low';
      } else if (v <= 180) {
        statusColor = AppColors.inRange;
        statusLabel = 'In Range';
      } else {
        statusColor = AppColors.high;
        statusLabel = 'High';
      }
    }

    IconData trendIcon;
    switch (trend) {
      case 'rising':
        trendIcon = Icons.trending_up_rounded;
        break;
      case 'falling':
        trendIcon = Icons.trending_down_rounded;
        break;
      default:
        trendIcon = Icons.trending_flat_rounded;
    }

    final updatedText = _lastUpdate == null
        ? 'Waiting for CGM…'
        : 'Updated ${DateTime.now().difference(_lastUpdate!).inMinutes}m ago';

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Current Glucose',
                  style: GoogleFonts.splineSans(
                      fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(width: 6),
              Icon(trendIcon, size: 16, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: GoogleFonts.splineSans(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain)),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 6),
                child: Text('mg/dL',
                    style: GoogleFonts.splineSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: GoogleFonts.splineSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
          const SizedBox(height: 8),
          Text(updatedText,
              style: GoogleFonts.splineSans(
                  fontSize: 11, color: AppColors.textDim)),
        ],
      ),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Time in Range',
                  style: GoogleFonts.splineSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain)),
              Text('${tir.toStringAsFixed(0)}%',
                  style: GoogleFonts.splineSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inRange)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _tirBar(tir, AppColors.inRange),
                const SizedBox(width: 2),
                _tirBar(tar, AppColors.high),
                const SizedBox(width: 2),
                _tirBar(tbr, AppColors.low),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tirLegend(AppColors.inRange, 'In Range ${tir.toStringAsFixed(0)}%'),
              const SizedBox(width: 16),
              _tirLegend(AppColors.high, 'High ${tar.toStringAsFixed(0)}%'),
              const SizedBox(width: 16),
              _tirLegend(AppColors.low, 'Low ${tbr.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tirBar(double pct, Color color) => Flexible(
        flex: pct.round().clamp(1, 100),
        child: Container(height: 10, color: color),
      );

  Widget _tirLegend(Color color, String label) => Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.splineSans(
                  fontSize: 11, color: AppColors.textMuted)),
        ],
      );

  Widget _buildStatsRow() {
    final stats = _report?['stats']?['stats'];
    final variability = _report?['variability'];
    final avg = stats?['average']?.toStringAsFixed(0) ?? '--';
    final gmi = stats?['gmi']?.toStringAsFixed(1) ?? '--';
    final cv = variability?['cv']?.toStringAsFixed(0) ?? '--';

    return Row(
      children: [
        _StatChip(label: 'Avg Glucose', value: avg, unit: 'mg/dL'),
        const SizedBox(width: 12),
        _StatChip(label: 'Est. GMI', value: gmi, unit: '%'),
        const SizedBox(width: 12),
        _StatChip(label: 'CV', value: cv, unit: '%'),
      ],
    );
  }

  Widget _buildDawnCard() {
    final dawn = _report?['dawn_phenomenon'];
    if (dawn == null) return const SizedBox.shrink();
    final detected = dawn['detected'] == true;
    final rise = (dawn['average_rise'] ?? 0).toStringAsFixed(1);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.high.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wb_twilight_rounded,
                color: AppColors.high, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dawn Phenomenon',
                    style: GoogleFonts.splineSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain)),
                Text(
                    detected
                        ? 'Detected — avg rise +$rise mg/dL'
                        : 'Not detected this week',
                    style: GoogleFonts.splineSans(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: detected
                  ? AppColors.high.withValues(alpha: 0.15)
                  : AppColors.inRange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              detected ? 'Yes' : 'No',
              style: GoogleFonts.splineSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: detected ? AppColors.high : AppColors.inRange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatterns() {
    final patterns = _report?['patterns'];
    if (patterns == null) return const SizedBox.shrink();

    final periods = [
      ('Morning', patterns['morning']),
      ('Afternoon', patterns['afternoon']),
      ('Evening', patterns['evening']),
      ('Night', patterns['night']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Patterns',
            style: GoogleFonts.splineSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain)),
        const SizedBox(height: 10),
        ...periods.map((p) {
          final data = p.$2;
          if (data == null) return const SizedBox.shrink();
          final avgVal = (data['avg'] ?? 0).toDouble();
          final Color dotColor = avgVal > 180
              ? AppColors.high
              : avgVal < 70
                  ? AppColors.low
                  : AppColors.inRange;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${avgVal.toStringAsFixed(0)} mg/dL',
                            style: GoogleFonts.splineSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain)),
                        Text(
                            '${p.$1}  •  ${data['time'] ?? ''}  •  ${data['reading'] ?? 0} readings',
                            style: GoogleFonts.splineSans(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }


  Widget _buildErrorCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: AppColors.textDim),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Could not load report data',
                style: GoogleFonts.splineSans(
                    fontSize: 13, color: AppColors.textMuted)),
          ),
          GestureDetector(
            onTap: _loadReport,
            child: Text('Retry',
                style: GoogleFonts.splineSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: AppTheme.cardDecoration,
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.splineSans(
                    fontSize: 10, color: AppColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.splineSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain)),
            Text(unit,
                style: GoogleFonts.splineSans(
                    fontSize: 10, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}

