import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that persists the user's profile and app settings locally.
/// All screens read from and write to this service instead of hardcoding values.
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._();
  factory UserProfileService() => _instance;
  UserProfileService._();

  SharedPreferences? _prefs;

  // ── Profile
  String get name => _prefs?.getString('name') ?? 'User';
  int get age => _prefs?.getInt('age') ?? 0;
  int get weight => _prefs?.getInt('weight') ?? 0;
  int get height => _prefs?.getInt('height') ?? 0;
  int get basalUnit => _prefs?.getInt('basal_unit') ?? 18;
  String get diabetesType => _prefs?.getString('diabetes_type') ?? 'Type 1';

  // ── App preferences
  String get glucoseUnit => _prefs?.getString('glucose_unit') ?? 'mg/dL';

  // ── Health targets
  int get targetLow => _prefs?.getInt('target_low') ?? 70;
  int get targetHigh => _prefs?.getInt('target_high') ?? 180;

  // ── Alert thresholds
  int get hypoThreshold => _prefs?.getInt('hypo_threshold') ?? 70;
  int get highThreshold => _prefs?.getInt('high_threshold') ?? 250;
  int get hypoCheckMinutes => _prefs?.getInt('hypo_check_min') ?? 15;
  int get highCheckMinutes => _prefs?.getInt('high_check_min') ?? 30;
  bool get alertsEnabled => _prefs?.getBool('alerts_enabled') ?? true;
  bool get hypoRemindEat => _prefs?.getBool('hypo_remind_eat') ?? true;
  bool get highRemindInject => _prefs?.getBool('high_remind_inject') ?? true;
  bool get hypoAlertEnabled => _prefs?.getBool('hypo_alert_enabled') ?? true;
  bool get highAlertEnabled => _prefs?.getBool('high_alert_enabled') ?? true;

  // ── Juggluco
  String get jugglucoUrl => _prefs?.getString('juggluco_url') ?? 'http://127.0.0.1:17580';
  bool get jugglucoEnabled => _prefs?.getBool('juggluco_enabled') ?? true;
  int get jugglucoPollSeconds => _prefs?.getInt('juggluco_poll_sec') ?? 120;

  bool get isProfileComplete =>
      name.isNotEmpty && name != 'User' && age > 0 && weight > 0 && height > 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveProfile({
    required String name,
    required int age,
    required int weight,
    required int height,
    required int basalUnit,
    String diabetesType = 'Type 1',
  }) async {
    await _prefs?.setString('name', name);
    await _prefs?.setInt('age', age);
    await _prefs?.setInt('weight', weight);
    await _prefs?.setInt('height', height);
    await _prefs?.setInt('basal_unit', basalUnit);
    await _prefs?.setString('diabetes_type', diabetesType);
  }

  Future<void> saveTargets({required int low, required int high}) async {
    await _prefs?.setInt('target_low', low);
    await _prefs?.setInt('target_high', high);
  }

  Future<void> saveAlertSettings({
    required bool alertsEnabled,
    required int hypoThreshold,
    required int highThreshold,
    required int hypoCheckMinutes,
    required int highCheckMinutes,
    required bool hypoRemindEat,
    required bool highRemindInject,
  }) async {
    await _prefs?.setBool('alerts_enabled', alertsEnabled);
    await _prefs?.setInt('hypo_threshold', hypoThreshold);
    await _prefs?.setInt('high_threshold', highThreshold);
    await _prefs?.setInt('hypo_check_min', hypoCheckMinutes);
    await _prefs?.setInt('high_check_min', highCheckMinutes);
    await _prefs?.setBool('hypo_remind_eat', hypoRemindEat);
    await _prefs?.setBool('high_remind_inject', highRemindInject);
  }

  Future<void> saveJugglucoSettings({
    required String url,
    required bool enabled,
    required int pollSeconds,
  }) async {
    await _prefs?.setString('juggluco_url', url);
    await _prefs?.setBool('juggluco_enabled', enabled);
    await _prefs?.setInt('juggluco_poll_sec', pollSeconds);
  }

  // ── Granular setters ────────────────────────────────────────────────────────

  Future<void> setGlucoseUnit(String unit) async {
    await _prefs?.setString('glucose_unit', unit);
  }

  Future<void> setHypoAlertEnabled(bool value) async {
    await _prefs?.setBool('hypo_alert_enabled', value);
  }

  Future<void> setHighAlertEnabled(bool value) async {
    await _prefs?.setBool('high_alert_enabled', value);
  }
}
