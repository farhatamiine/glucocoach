import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shared [FlutterLocalNotificationsPlugin] instance.
/// Both [AlertService] and [WellnessService] import [notificationPlugin] from here.
/// Call [initNotificationPlugin] exactly once in main() before any service that
/// sends notifications.
final FlutterLocalNotificationsPlugin notificationPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotificationPlugin() async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  );
  await notificationPlugin.initialize(settings);
}
