import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import 'log_hypo_screen.dart';

class HypoTrackerScreen extends StatefulWidget {
  const HypoTrackerScreen({super.key});

  @override
  State<HypoTrackerScreen> createState() => _HypoTrackerScreenState();
}

class _HypoTrackerScreenState extends State<HypoTrackerScreen> {
  final _api = ApiService();
  List<dynamic> _hypos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getHypos(limit: 50);
      setState(() { _hypos = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Computed summary stats
  int get _totalEvents => _hypos.length;

  double? get _avgLowest {
    if (_hypos.isEmpty) return null;
    final sum = _hypos.fold<double>(
        0, (s, h) => s + ((h['lowest_value'] ?? 0) as num).toDouble());
    return sum / _hypos.length;
  }

  double? get _avgDuration {
    final withDuration = _hypos.where((h) => h['duration_min'] != null).toList();
    if (withDuration.isEmpty) return null;
    final sum = withDuration.fold<double>(
        0, (s, h) => s + ((h['duration_min'] ?? 0) as num).toDouble());
    return sum / withDuration.length;
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
        title: Text('Hypo Tracker',
            style: GoogleFonts.splineSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded,
                color: AppColors.primary, size: 24),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LogHypoScreen()));
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceSolid,
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildSummaryCard(),
                            const SizedBox(height: 20),
                            Text('Recent Events',
                                style: GoogleFonts.splineSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMain)),
                            const SizedBox(height: 12),
                            if (_hypos.isEmpty)
                              _buildEmpty()
                            else
                              ..._hypos.map(_buildHypoCard),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary',
              style: GoogleFonts.splineSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain)),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryItem(
                label: 'Total Events',
                value: '$_totalEvents',
                color: AppColors.low,
              ),
              _SummaryItem(
                label: 'Avg Lowest',
                value: _avgLowest != null
                    ? '${_avgLowest!.toStringAsFixed(0)} mg/dL'
                    : '--',
                color: AppColors.primary,
              ),
              _SummaryItem(
                label: 'Avg Duration',
                value: _avgDuration != null
                    ? '${_avgDuration!.toStringAsFixed(0)} min'
                    : '--',
                color: AppColors.high,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHypoCard(dynamic hypo) {
    final lowest = (hypo['lowest_value'] ?? 0).toStringAsFixed(0);
    final startedAt = hypo['started_at'] as String?;
    final duration = hypo['duration_min'];
    final treatedWith = hypo['treated_with'] as String?;

    DateTime? dt;
    if (startedAt != null) {
      try { dt = DateTime.parse(startedAt).toLocal(); } catch (_) {}
    }

    final dateStr = dt != null
        ? '${_monthName(dt.month)} ${dt.day}  •  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '--';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.low.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text('$lowest',
                  style: GoogleFonts.splineSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.low)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: GoogleFonts.splineSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain)),
                  const SizedBox(height: 3),
                  Text([
                    if (duration != null) '${duration}min',
                    if (treatedWith != null && treatedWith.isNotEmpty)
                      treatedWith,
                  ].join('  •  ').isNotEmpty
                      ? [
                          if (duration != null) '${duration}min',
                          if (treatedWith != null && treatedWith.isNotEmpty)
                            treatedWith,
                        ].join('  •  ')
                      : 'No treatment logged',
                      style: GoogleFonts.splineSans(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.inRange, size: 48),
            const SizedBox(height: 12),
            Text('No hypo events logged',
                style: GoogleFonts.splineSans(
                    fontSize: 15, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.textDim, size: 40),
          const SizedBox(height: 12),
          Text('Could not load hypo events',
              style: GoogleFonts.splineSans(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _load,
            child: Text('Retry',
                style: GoogleFonts.splineSans(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.splineSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color),
              textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.splineSans(
                  fontSize: 10, color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
