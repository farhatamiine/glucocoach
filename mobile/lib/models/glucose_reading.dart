class GlucoseReading {
  final double value;
  final DateTime time;
  final String trend; // 'rising_fast', 'rising', 'stable', 'falling', 'falling_fast'

  const GlucoseReading({
    required this.value,
    required this.time,
    required this.trend,
  });

  bool get isHypo => value <= 70;
  bool get isLow => value < 80;
  bool get isHigh => value > 180;
  bool get isVeryHigh => value > 250;
  bool get isInRange => value >= 70 && value <= 180;

  String get trendArrow {
    switch (trend) {
      case 'rising_fast':
        return '↑↑';
      case 'rising':
        return '↑';
      case 'falling_fast':
        return '↓↓';
      case 'falling':
        return '↓';
      default:
        return '→';
    }
  }

  /// Parse Juggluco /json response array item.
  /// Juggluco returns: {"DT": epoch_ms, "Value": 120, "direction": "Flat"} or similar variants.
  factory GlucoseReading.fromJuggluco(Map<String, dynamic> json) {
    // Value field — Juggluco uses "Value" or "sgv" or "glucose"
    final rawValue = json['Value'] ?? json['sgv'] ?? json['glucose'] ?? json['value'] ?? 0;
    final value = (rawValue as num).toDouble();

    // Time field — Juggluco uses "DT" (epoch ms) or "time" or "Date"
    DateTime time;
    if (json.containsKey('DT')) {
      time = DateTime.fromMillisecondsSinceEpoch((json['DT'] as num).toInt());
    } else if (json.containsKey('time')) {
      final t = json['time'];
      if (t is num) {
        // Could be seconds or ms — ms are > 1e12
        time = t > 1e12
            ? DateTime.fromMillisecondsSinceEpoch(t.toInt())
            : DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000);
      } else {
        time = DateTime.tryParse(t.toString()) ?? DateTime.now();
      }
    } else {
      time = DateTime.now();
    }

    // Trend field
    final rawTrend = (json['direction'] ?? json['trend'] ?? json['Trend'] ?? '').toString();
    String trend;
    switch (rawTrend.toLowerCase()) {
      case 'doubleup':
      case 'rapidlyincreasing':
        trend = 'rising_fast';
      case 'singleup':
      case 'fortyfiveup':
      case 'increasing':
        trend = 'rising';
      case 'singledown':
      case 'fortyfivedown':
      case 'decreasing':
        trend = 'falling';
      case 'doubledown':
      case 'rapidlydecreasing':
        trend = 'falling_fast';
      default:
        trend = 'stable';
    }

    return GlucoseReading(value: value, time: time, trend: trend);
  }
}
