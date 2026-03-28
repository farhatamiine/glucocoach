import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/glucose_reading.dart';
import 'juggluco_service.dart';
import 'notification_plugin.dart';
import 'user_profile_service.dart';

/// Listens to Juggluco readings and fires notifications for hypo/high events.
/// Also schedules check-back alerts after a configurable delay.
class AlertService {
  static final AlertService _instance = AlertService._();
  factory AlertService() => _instance;
  AlertService._();

  final _profile = UserProfileService();
  final _juggluco = JugglucoService();

  StreamSubscription<GlucoseReading>? _sub;

  // Tracks last alert times to avoid spamming
  DateTime? _lastHypoAlert;
  DateTime? _lastHighAlert;

  // Streams so UI can react (e.g. open LogHypo dialog)
  final _hypoController = StreamController<GlucoseReading>.broadcast();
  final _highController = StreamController<GlucoseReading>.broadcast();

  Stream<GlucoseReading> get onHypo => _hypoController.stream;
  Stream<GlucoseReading> get onHigh => _highController.stream;

  Future<void> init() async {
    // Create notification channels for Android
    const channel = AndroidNotificationChannel(
      'glucose_alerts',
      'Glucose Alerts',
      description: 'Alerts for high and low blood glucose',
      importance: Importance.high,
    );
    await notificationPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _startListening();
  }

  void _startListening() {
    _sub?.cancel();
    _sub = _juggluco.stream.listen(_onReading);
  }

  void _onReading(GlucoseReading reading) {
    if (!_profile.alertsEnabled) return;

    final now = DateTime.now();

    if (reading.value <= _profile.hypoThreshold) {
      // Hypo — only alert if last alert was more than hypoCheckMinutes ago
      final lastAlert = _lastHypoAlert;
      if (lastAlert == null ||
          now.difference(lastAlert).inMinutes >= _profile.hypoCheckMinutes) {
        _lastHypoAlert = now;
        _fireHypoAlert(reading);
        _hypoController.add(reading);

        // Schedule check-back
        Timer(Duration(minutes: _profile.hypoCheckMinutes), () {
          _scheduleHypoCheckBack();
        });
      }
    } else if (reading.value >= _profile.highThreshold) {
      // High
      final lastAlert = _lastHighAlert;
      if (lastAlert == null ||
          now.difference(lastAlert).inMinutes >= _profile.highCheckMinutes) {
        _lastHighAlert = now;
        _fireHighAlert(reading);
        _highController.add(reading);

        Timer(Duration(minutes: _profile.highCheckMinutes), () {
          _scheduleHighCheckBack();
        });
      }
    } else {
      // Back in range — reset cooldowns so next event fires immediately
      if (_lastHypoAlert != null) {
        _lastHypoAlert = null;
        _notify(
          id: 10,
          title: '✅ Glucose recovering',
          body: 'BG is now ${reading.value.toStringAsFixed(0)} mg/dL — back on track.',
          channelId: 'glucose_alerts',
        );
      }
      if (_lastHighAlert != null) {
        _lastHighAlert = null;
        _notify(
          id: 11,
          title: '✅ Glucose coming down',
          body: 'BG is now ${reading.value.toStringAsFixed(0)} mg/dL — improving.',
          channelId: 'glucose_alerts',
        );
      }
    }
  }

  void _fireHypoAlert(GlucoseReading reading) {
    _notify(
      id: 1,
      title: '🍬 Low glucose! Eat fast carbs now',
      body: 'BG is ${reading.value.toStringAsFixed(0)} mg/dL ${reading.trendArrow}. '
          'Eat 15g of fast carbs (juice, glucose tablets).',
      channelId: 'glucose_alerts',
    );
  }

  void _fireHighAlert(GlucoseReading reading) {
    _notify(
      id: 2,
      title: '💉 High glucose detected',
      body: 'BG is ${reading.value.toStringAsFixed(0)} mg/dL ${reading.trendArrow}. '
          'Consider a correction bolus.',
      channelId: 'glucose_alerts',
    );
  }

  void _scheduleHypoCheckBack() {
    final last = _juggluco.lastReading;
    if (last == null) return;
    if (last.value <= _profile.hypoThreshold) {
      _notify(
        id: 3,
        title: '⚠️ Still low after ${_profile.hypoCheckMinutes} min',
        body: 'BG is ${last.value.toStringAsFixed(0)} mg/dL. Did you eat? Eat more if not improving.',
        channelId: 'glucose_alerts',
      );
    }
    // If rising, _onReading handles the "back in range" message
  }

  void _scheduleHighCheckBack() {
    final last = _juggluco.lastReading;
    if (last == null) return;
    if (last.value >= _profile.highThreshold) {
      _notify(
        id: 4,
        title: '⚠️ Still high after ${_profile.highCheckMinutes} min',
        body: 'BG is ${last.value.toStringAsFixed(0)} mg/dL. May need additional correction.',
        channelId: 'glucose_alerts',
      );
    }
  }

  Future<void> _notify({
    required int id,
    required String title,
    required String body,
    required String channelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Glucose Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);
    await notificationPlugin.show(id, title, body, details);
  }

  void dispose() {
    _sub?.cancel();
    _hypoController.close();
    _highController.close();
  }
}
