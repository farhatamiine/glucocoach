import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/glucose_reading.dart';
import 'user_profile_service.dart';

/// Polls the Juggluco local web server for real-time glucose readings.
/// Juggluco must have its web server enabled (Settings → Web server).
/// Default URL: http://127.0.0.1:17580
class JugglucoService {
  static final JugglucoService _instance = JugglucoService._();
  factory JugglucoService() => _instance;
  JugglucoService._();

  final _profile = UserProfileService();
  final _controller = StreamController<GlucoseReading>.broadcast();
  Timer? _timer;
  GlucoseReading? _lastReading;
  List<GlucoseReading> _cachedReadings = [];

  Stream<GlucoseReading> get stream => _controller.stream;
  GlucoseReading? get lastReading => _lastReading;

  void start() {
    if (_timer != null) return; // already running
    _poll(); // immediate first fetch
    final interval = Duration(seconds: _profile.jugglucoPollSeconds);
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void restart() {
    stop();
    start();
  }

  Future<void> _poll() async {
    if (!_profile.jugglucoEnabled) {
      print('[Juggluco] Polling skipped — jugglucoEnabled=false');
      return;
    }
    print('[Juggluco] Polling ${_profile.jugglucoUrl} ...');
    try {
      final readings = await _fetchReadings();
      if (readings.isNotEmpty) {
        _cachedReadings = readings;
        final latest = readings.first;
        _lastReading = latest;
        _controller.add(latest);
        print('[Juggluco] ✓ Got ${readings.length} readings — latest: ${latest.value} mg/dL @ ${latest.time} trend=${latest.trend}');
      } else {
        print('[Juggluco] ✗ _fetchReadings() returned empty list');
      }
    } catch (e, st) {
      print('[Juggluco] ✗ _poll() exception: $e');
      print(st);
    }
  }

  /// Fetches the latest readings from Juggluco.
  /// Uses a raw TCP socket to bypass Dart's strict Content-Length header validation
  /// (Juggluco sends non-numeric Content-Length values that dart:io rejects).
  ///
  /// Endpoint priority:
  ///   1. /api/v1/entries/sgv.json — Nightscout-compatible JSON (cleanest)
  ///   2. /x/stream                — proprietary text format
  ///   3. /json                    — legacy JSON fallback
  Future<List<GlucoseReading>> _fetchReadings() async {
    final base = _profile.jugglucoUrl;
    final uri = Uri.parse(base);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 17580;

    for (final path in ['/api/v1/entries/sgv.json', '/x/stream', '/json']) {
      final body = await _rawGet(host, port, path);
      if (body == null || body.isEmpty) continue;
      print('[Juggluco] $path → body preview: ${body.substring(0, body.length.clamp(0, 300))}');

      List<GlucoseReading> readings;
      if (path == '/api/v1/entries/sgv.json') {
        readings = _parseSgvJson(body);
      } else if (body.startsWith('[') || body.startsWith('{')) {
        print('[Juggluco] Detected legacy JSON on $path');
        readings = _parseJsonBody(body);
      } else {
        print('[Juggluco] Detected text format on $path');
        readings = _parseTextBody(body);
      }
      print('[Juggluco] $path parsed ${readings.length} readings');
      if (readings.isNotEmpty) return readings;
    }

    print('[Juggluco] All endpoints failed — returning empty');
    return [];
  }

  /// Raw TCP GET request — bypasses Dart's HTTP header validation entirely.
  /// Juggluco sends invalid Content-Length headers that dart:io/http reject.
  Future<String?> _rawGet(String host, int port, String path) async {
    try {
      print('[Juggluco] RAW GET $host:$port$path');
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));

      // HTTP/1.0 avoids chunked-transfer complications
      socket.write(
        'GET $path HTTP/1.0\r\n'
        'Host: $host:$port\r\n'
        'Connection: close\r\n'
        '\r\n',
      );
      await socket.flush();

      final bytes = <int>[];
      await socket.listen(bytes.addAll).asFuture<void>().catchError((_) {});
      socket.destroy();

      if (bytes.isEmpty) {
        print('[Juggluco] RAW GET $path — empty response');
        return null;
      }

      // Split raw HTTP response into headers + body on \r\n\r\n
      final raw = String.fromCharCodes(bytes);
      final sep = raw.indexOf('\r\n\r\n');
      final body = sep >= 0 ? raw.substring(sep + 4).trim() : raw.trim();
      print('[Juggluco] RAW GET $path → ${bytes.length} bytes, body ${body.length} chars');
      return body.isEmpty ? null : body;
    } catch (e) {
      print('[Juggluco] RAW GET $host:$port$path exception: $e');
      return null;
    }
  }

  /// Parse JSON response from Juggluco /json endpoint.
  List<GlucoseReading> _parseJsonBody(String body) {
    try {
      List<dynamic> raw;
      if (body.startsWith('[')) {
        raw = json.decode(body) as List<dynamic>;
      } else {
        raw = [json.decode(body)];
      }
      final readings = raw
          .whereType<Map<String, dynamic>>()
          .map((m) => GlucoseReading.fromJuggluco(m))
          .toList();
      readings.sort((a, b) => b.time.compareTo(a.time));
      return readings;
    } catch (_) {
      return [];
    }
  }

  /// Parse plain-text response from Juggluco.
  /// Format (two lines per reading):
  ///   <serial> <index> <unix_ts_sec> <iso_datetime> <flags> <glucose_mgdl> <raw> <delta>
  ///   <TREND>
  /// e.g.:
  ///   301WH68HMA4  1  1773409220  2026-03-13T13:40:20  0  119  77  -0.55
  ///   STABLE
  List<GlucoseReading> _parseTextBody(String body) {
    final readings = <GlucoseReading>[];
    try {
      print('[Juggluco] _parseTextBody: raw body (first 400 chars): ${body.substring(0, body.length.clamp(0, 400))}');
      final lines = body
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      print('[Juggluco] _parseTextBody: ${lines.length} non-empty lines');

      int i = 0;
      while (i < lines.length) {
        final dataLine = lines[i];
        final trendLine = (i + 1 < lines.length) ? lines[i + 1] : 'STABLE';

        // Skip if trend line looks like another data line (has numbers)
        // Data line should have at least 6 whitespace-separated fields
        final fields = dataLine.split(RegExp(r'\s+'));
        if (fields.length < 6) { i++; continue; }

        // Field[2] = unix timestamp (seconds), Field[5] = glucose mg/dL
        final tsRaw = int.tryParse(fields[2]);
        final glucoseRaw = double.tryParse(fields[5]);

        if (tsRaw == null || glucoseRaw == null || glucoseRaw < 20 || glucoseRaw > 600) {
          i++;
          continue;
        }

        final time = DateTime.fromMillisecondsSinceEpoch(tsRaw * 1000);

        // Parse trend from next line
        String trend;
        final trendUpper = trendLine.toUpperCase();
        if (trendUpper.contains('RISING FAST') || trendUpper.contains('RAPIDLYINCREASING')) {
          trend = 'rising_fast';
        } else if (trendUpper.contains('FALLING FAST') || trendUpper.contains('RAPIDLYDECREASING')) {
          trend = 'falling_fast';
        } else if (trendUpper.contains('RISING') || trendUpper == 'UP') {
          trend = 'rising';
        } else if (trendUpper.contains('FALLING') || trendUpper == 'DOWN') {
          trend = 'falling';
        } else {
          trend = 'stable';
        }

        readings.add(GlucoseReading(value: glucoseRaw, time: time, trend: trend));

        // Advance by 2 if trend line was consumed, else 1
        final trendLooksLikeData = trendLine.split(RegExp(r'\s+')).length >= 6;
        i += trendLooksLikeData ? 1 : 2;
      }

      readings.sort((a, b) => b.time.compareTo(a.time));
    } catch (_) {}
    return readings;
  }

  /// Parse Nightscout-compatible SGV JSON from /api/v1/entries/sgv.json.
  /// Each entry: { "sgv": 120, "date": 1773409220000, "direction": "Flat", ... }
  List<GlucoseReading> _parseSgvJson(String body) {
    try {
      final List<dynamic> raw = json.decode(body) as List<dynamic>;
      final readings = raw.whereType<Map<String, dynamic>>().map((m) {
        final sgv = (m['sgv'] as num?)?.toDouble();
        final dateMs = (m['date'] as num?)?.toInt();
        final direction = (m['direction'] as String?) ?? 'Flat';

        if (sgv == null || dateMs == null || sgv < 20 || sgv > 600) return null;

        final time = DateTime.fromMillisecondsSinceEpoch(dateMs);
        final trend = _directionToTrend(direction);
        return GlucoseReading(value: sgv, time: time, trend: trend);
      }).whereType<GlucoseReading>().toList();

      readings.sort((a, b) => b.time.compareTo(a.time));
      return readings;
    } catch (e) {
      print('[Juggluco] _parseSgvJson error: $e');
      return [];
    }
  }

  String _directionToTrend(String direction) {
    switch (direction) {
      case 'DoubleUp':        return 'rising_fast';
      case 'SingleUp':
      case 'FortyFiveUp':    return 'rising';
      case 'Flat':           return 'stable';
      case 'FortyFiveDown':
      case 'SingleDown':     return 'falling';
      case 'DoubleDown':     return 'falling_fast';
      default:               return 'stable';
    }
  }

  /// Returns the current live reading (from last poll).
  Future<GlucoseReading?> fetchCurrent() async {
    if (!_profile.jugglucoEnabled) return null;
    try {
      final readings = await _fetchReadings();
      if (readings.isNotEmpty) {
        _lastReading = readings.first;
        return _lastReading;
      }
    } catch (_) {}
    return _lastReading;
  }

  /// Returns the reading closest to [targetTime] from cached or freshly fetched data.
  Future<GlucoseReading?> fetchAtTime(DateTime targetTime) async {
    if (!_profile.jugglucoEnabled) return null;
    try {
      List<GlucoseReading> readings = _cachedReadings.isNotEmpty
          ? _cachedReadings
          : await _fetchReadings();

      if (readings.isEmpty) return null;

      readings.sort((a, b) =>
          (a.time.difference(targetTime).inSeconds.abs())
              .compareTo(b.time.difference(targetTime).inSeconds.abs()));

      // Only return if within 15 minutes of the target
      final closest = readings.first;
      if (closest.time.difference(targetTime).inMinutes.abs() <= 15) {
        return closest;
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
