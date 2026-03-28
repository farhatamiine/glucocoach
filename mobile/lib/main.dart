import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/alert_service.dart';
import 'services/auth_service.dart';
import 'services/juggluco_service.dart';
import 'services/notification_plugin.dart';
import 'services/offline_cache_service.dart';
import 'services/user_profile_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 1. Auth + profile
  await AuthService().init();
  await UserProfileService().init();
  await OfflineCacheService().init();

  // 2. Notifications
  await initNotificationPlugin();

  // 3. Timezones
  tz.initializeTimeZones();
  final tzInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

  // 4. Alert service
  await AlertService().init();

  // 5. CGM polling
  JugglucoService().start();

  runApp(const CgmApp());
}

class CgmApp extends StatelessWidget {
  const CgmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlucoCoach',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: AuthService().isLoggedIn
          ? const MainScreen()
          : const LoginScreen(),
    );
  }
}
