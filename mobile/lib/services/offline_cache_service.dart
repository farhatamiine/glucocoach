import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Stores pending API logs when offline and syncs them when back online.
/// Also maintains a local daily log of bolus/basal entries for display on log screens.
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._();

  static const _queueKey = 'offline_queue';
  static const _dailyLogKey = 'daily_log';

  SharedPreferences? _prefs;
  final _api = ApiService();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Listen for connectivity restored → try to sync
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncPending();
      }
    });
  }

  // ── Offline Queue ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _getQueue() {
    final raw = _prefs?.getString(_queueKey);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await _prefs?.setString(_queueKey, json.encode(queue));
  }

  Future<void> _enqueue(String type, Map<String, dynamic> data) async {
    final queue = _getQueue();
    queue.add({
      'type': type,
      'data': data,
      'ts': DateTime.now().toIso8601String(),
    });
    await _saveQueue(queue);
  }

  /// Try to flush all pending offline logs to the API.
  Future<void> syncPending() async {
    final queue = _getQueue();
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        await _executeQueueItem(item);
      } catch (_) {
        remaining.add(item); // keep for next attempt
      }
    }
    await _saveQueue(remaining);
  }

  Future<void> _executeQueueItem(Map<String, dynamic> item) async {
    final type = item['type'] as String;
    final data = item['data'] as Map<String, dynamic>;

    switch (type) {
      case 'bolus':
        await _api.logBolus(
          units: (data['units'] as num).toDouble(),
          bolusType: data['bolus_type'] ?? 'manual',
          mealType: data['meal_type'],
          glucoseAtInjection: data['glucose_at_injection'] != null
              ? (data['glucose_at_injection'] as num).toDouble()
              : null,
          notes: data['notes'],
        );
      case 'basal':
        await _api.logBasal(
          units: (data['units'] as num).toDouble(),
          insulin: data['insulin'],
          time: data['time'],
          notes: data['notes'],
        );
      case 'hypo':
        await _api.logHypo(
          lowestValue: (data['lowest_value'] as num).toDouble(),
          startedAt: DateTime.parse(data['started_at']),
          durationMin: data['duration_min'],
          treatedWith: data['treated_with'],
          notes: data['notes'],
        );
    }
  }

  // ── Offline-aware log methods ────────────────────────────────────────────────

  /// Log bolus — tries API, queues locally if offline.
  /// Always adds to today's local log.
  Future<void> logBolus({
    required double units,
    required String bolusType,
    String? mealType,
    double? glucoseAtInjection,
    String? notes,
    DateTime? loggedAt,
  }) async {
    final data = {
      'units': units,
      'bolus_type': bolusType,
      'meal_type': ?mealType,
      'glucose_at_injection': ?glucoseAtInjection,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    bool savedToApi = false;
    try {
      await _api.logBolus(
        units: units,
        bolusType: bolusType,
        mealType: mealType,
        glucoseAtInjection: glucoseAtInjection,
        notes: notes,
      );
      savedToApi = true;
    } catch (_) {
      await _enqueue('bolus', data);
    }

    // Always record to daily log
    await _addToDailyLog('bolus', {
      'units': units,
      'type': bolusType,
      'meal_type': mealType,
      'time': (loggedAt ?? DateTime.now()).toIso8601String(),
      'pending': !savedToApi,
    });
  }

  /// Log basal — tries API, queues locally if offline.
  Future<void> logBasal({
    required double units,
    required String insulin,
    required String time,
    String? notes,
    DateTime? loggedAt,
  }) async {
    final data = {
      'units': units,
      'insulin': insulin,
      'time': time,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    bool savedToApi = false;
    try {
      await _api.logBasal(
        units: units,
        insulin: insulin,
        time: time,
        notes: notes,
      );
      savedToApi = true;
    } catch (_) {
      await _enqueue('basal', data);
    }

    await _addToDailyLog('basal', {
      'units': units,
      'insulin': insulin,
      'time': (loggedAt ?? DateTime.now()).toIso8601String(),
      'pending': !savedToApi,
    });
  }

  /// Log hypo — tries API, queues locally if offline.
  Future<void> logHypo({
    required double lowestValue,
    required DateTime startedAt,
    int? durationMin,
    String? treatedWith,
    String? notes,
  }) async {
    final data = {
      'lowest_value': lowestValue,
      'started_at': startedAt.toIso8601String(),
      'duration_min': ?durationMin,
      'treated_with': ?treatedWith,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    try {
      await _api.logHypo(
        lowestValue: lowestValue,
        startedAt: startedAt,
        durationMin: durationMin,
        treatedWith: treatedWith,
        notes: notes,
      );
    } catch (_) {
      await _enqueue('hypo', data);
    }
  }

  // ── Daily Log ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _getDailyLog() {
    final today = _todayKey();
    final raw = _prefs?.getString('$_dailyLogKey.$today');
    if (raw == null) return {'boluses': [], 'basals': []};
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {'boluses': [], 'basals': []};
    }
  }

  Future<void> _addToDailyLog(String type, Map<String, dynamic> entry) async {
    final log = _getDailyLog();
    final list = (log['${type}s'] as List? ?? []).cast<dynamic>();
    list.add(entry);
    log['${type}s'] = list;
    await _prefs?.setString('$_dailyLogKey.${_todayKey()}', json.encode(log));
  }

  /// Returns today's bolus list: [{units, type, time, pending}, ...]
  List<Map<String, dynamic>> getTodayBoluses() {
    final log = _getDailyLog();
    return (log['boluses'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Returns today's basal list: [{units, insulin, time, pending}, ...]
  List<Map<String, dynamic>> getTodayBasals() {
    final log = _getDailyLog();
    return (log['basals'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  double getTodayTotalBolus() {
    return getTodayBoluses().fold(
      0,
      (sum, e) => sum + ((e['units'] as num?) ?? 0).toDouble(),
    );
  }

  double getTodayTotalBasal() {
    return getTodayBasals().fold(
      0,
      (sum, e) => sum + ((e['units'] as num?) ?? 0).toDouble(),
    );
  }

  int getPendingCount() => _getQueue().length;

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
