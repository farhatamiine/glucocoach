# Wellness Reminders Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Wellness screen with daily water intake goal tracking and per-vitamin reminder notifications, accessible from the existing Log Hub tab.

**Architecture:** A shared `FlutterLocalNotificationsPlugin` singleton in `notification_plugin.dart` is used by both `AlertService` and the new `WellnessService`. `WellnessService` extends `ChangeNotifier` and persists all state in SharedPreferences. `WellnessScreen` rebuilds via `ListenableBuilder` and is pushed from the Log Hub screen.

**Tech Stack:** Flutter/Dart, `flutter_local_notifications ^17.0.0`, `timezone ^0.9.0`, `flutter_timezone ^1.0.4`, `shared_preferences ^2.3.0`, `flutter/foundation.dart` (ChangeNotifier)

---

## Chunk 1: Foundation — packages, shared notification plugin, vitamin model

---

### Task 1: Add timezone packages to pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages**

Open `pubspec.yaml` and add under `dependencies:` (after `flutter_local_notifications`):

```yaml
  timezone: ^0.9.0
  flutter_timezone: ^1.0.4
```

- [ ] **Step 2: Install packages**

```bash
cd "C:/Users/afarhat/personal/New folder/cgm_app"
flutter pub get
```

Expected: `Got dependencies!` with no errors.

---

### Task 2: Create notification_plugin.dart — shared plugin singleton

**Files:**
- Create: `lib/services/notification_plugin.dart`
- Create: `test/services/notification_plugin_test.dart`

**Context:** Currently `AlertService` has a private `final _notifications = FlutterLocalNotificationsPlugin();` and calls `_notifications.initialize(settings)` in its `init()`. We need to extract this to a shared singleton so `WellnessService` can use the same instance. `initialize()` must only be called once.

- [ ] **Step 1: Create the shared plugin file**

Create `lib/services/notification_plugin.dart`:

```dart
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
```

- [ ] **Step 2: Write a smoke test**

Create `test/services/notification_plugin_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cgm_app/services/notification_plugin.dart';

void main() {
  test('notificationPlugin is a non-null singleton', () {
    final a = notificationPlugin;
    final b = notificationPlugin;
    expect(a, isNotNull);
    expect(identical(a, b), isTrue);
  });
}
```

- [ ] **Step 3: Run the test**

```bash
cd "C:/Users/afarhat/personal/New folder/cgm_app"
flutter test test/services/notification_plugin_test.dart
```

Expected: PASS (1 test).

---

### Task 3: Refactor AlertService to use the shared plugin

**Files:**
- Modify: `lib/services/alert_service.dart`

**Context:** `alert_service.dart` currently declares:
```dart
final _notifications = FlutterLocalNotificationsPlugin();
```
and calls `await _notifications.initialize(settings)` inside `init()`. Both must be removed; replace all `_notifications.` references with `notificationPlugin.`.

- [ ] **Step 1: Add import, remove private instance**

At the top of `lib/services/alert_service.dart`, add:
```dart
import 'notification_plugin.dart';
```

Remove this line from the class body:
```dart
final _notifications = FlutterLocalNotificationsPlugin();
```

- [ ] **Step 2: Remove the initialize() call**

Inside `init()`, delete the entire block that calls `_notifications.initialize(settings)` (the `const androidSettings`, `const iosSettings`, `const settings`, and `await _notifications.initialize(settings)` lines).

Also delete the channel creation block that uses `_notifications.resolvePlatformSpecificImplementation` — we will keep this but update it to use `notificationPlugin`:

Replace:
```dart
await _notifications
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
```
With:
```dart
await notificationPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
```

- [ ] **Step 3: Replace all remaining `_notifications.` with `notificationPlugin.`**

In `_notify()` method, replace:
```dart
await _notifications.show(id, title, body, details);
```
With:
```dart
await notificationPlugin.show(id, title, body, details);
```

- [ ] **Step 4: Verify app still builds**

```bash
cd "C:/Users/afarhat/personal/New folder/cgm_app"
flutter analyze lib/services/alert_service.dart
```

Expected: No errors (warnings about unused imports are fine to fix).

---

### Task 4: Create VitaminReminder model

**Files:**
- Create: `lib/models/vitamin_reminder.dart`
- Create: `test/models/vitamin_reminder_test.dart`

- [ ] **Step 1: Write the failing tests first**

Create `test/models/vitamin_reminder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cgm_app/models/vitamin_reminder.dart';

void main() {
  group('VitaminReminder', () {
    test('fromJson/toJson round-trips correctly', () {
      final v = VitaminReminder(
        id: 'vit_123_0',
        name: 'Vitamin D',
        hour: 8,
        minute: 30,
      );
      final json = v.toJson();
      final restored = VitaminReminder.fromJson(json);

      expect(restored.id, 'vit_123_0');
      expect(restored.name, 'Vitamin D');
      expect(restored.hour, 8);
      expect(restored.minute, 30);
    });

    test('uniqueId generates different ids for rapid calls', () {
      final id1 = VitaminReminder.uniqueId();
      final id2 = VitaminReminder.uniqueId();
      expect(id1, isNot(equals(id2)));
    });

    test('id starts with vit_', () {
      final id = VitaminReminder.uniqueId();
      expect(id.startsWith('vit_'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to see it fail**

```bash
flutter test test/models/vitamin_reminder_test.dart
```

Expected: FAIL — `vitamin_reminder.dart` does not exist.

- [ ] **Step 3: Create the model**

Create `lib/models/vitamin_reminder.dart`:

```dart
/// Represents a single vitamin/supplement with a daily reminder time.
/// [takenToday] is NOT stored here — it is computed at read time from
/// SharedPreferences key `wellness_taken_<id>_YYYY-MM-DD`.
class VitaminReminder {
  final String id;
  final String name;
  final int hour;
  final int minute;

  const VitaminReminder({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
  });

  // ── Unique ID generation ──────────────────────────────────────────────────

  static int _counter = 0;

  /// Generates a collision-resistant id: "vit_<epochMs>_<counter>".
  /// The static counter guarantees uniqueness even within the same millisecond.
  static String uniqueId() {
    _counter++;
    return 'vit_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
      };

  factory VitaminReminder.fromJson(Map<String, dynamic> json) =>
      VitaminReminder(
        id: json['id'] as String,
        name: json['name'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
flutter test test/models/vitamin_reminder_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock \
        lib/services/notification_plugin.dart \
        lib/services/alert_service.dart \
        lib/models/vitamin_reminder.dart \
        test/services/notification_plugin_test.dart \
        test/models/vitamin_reminder_test.dart
git commit -m "feat: shared notification plugin + VitaminReminder model"
```

---

## Chunk 2: WellnessService — water and vitamin state management

---

### Task 5: Create WellnessService skeleton + water state

**Files:**
- Create: `lib/services/wellness_service.dart`
- Create: `test/services/wellness_service_test.dart`

**Context:** `WellnessService` extends `ChangeNotifier` (from `package:flutter/foundation.dart`) and uses the same factory-constructor singleton pattern as `AlertService`:
```dart
static final WellnessService _instance = WellnessService._();
factory WellnessService() => _instance;
WellnessService._();
```
It reads/writes SharedPreferences and schedules notifications. The water count key is date-scoped: `wellness_water_count_YYYY-MM-DD`.

- [ ] **Step 1: Write failing tests for water state**

Create `test/services/wellness_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cgm_app/services/wellness_service.dart';

void main() {
  setUp(() async {
    // Reset SharedPreferences and service state before each test
    SharedPreferences.setMockInitialValues({});
    WellnessService.resetForTesting();
  });

  group('WellnessService — water defaults', () {
    test('waterGoal defaults to 8', () async {
      await WellnessService().init();
      expect(WellnessService().waterGoal, 8);
    });

    test('waterCount defaults to 0', () async {
      await WellnessService().init();
      expect(WellnessService().waterCount, 0);
    });

    test('waterReminderEnabled defaults to true', () async {
      await WellnessService().init();
      expect(WellnessService().waterReminderEnabled, isTrue);
    });

    test('waterIntervalHours defaults to 2', () async {
      await WellnessService().init();
      expect(WellnessService().waterIntervalHours, 2);
    });

    test('waterGoalReached is false when count is 0', () async {
      await WellnessService().init();
      expect(WellnessService().waterGoalReached, isFalse);
    });
  });

  group('WellnessService — addGlass', () {
    test('increments waterCount by 1', () async {
      await WellnessService().init();
      await WellnessService().addGlass();
      expect(WellnessService().waterCount, 1);
    });

    test('waterGoalReached becomes true when count reaches goal', () async {
      SharedPreferences.setMockInitialValues({'wellness_water_goal': 2});
      await WellnessService().init();
      await WellnessService().addGlass();
      await WellnessService().addGlass();
      expect(WellnessService().waterGoalReached, isTrue);
    });

    test('count is capped at goal * 2', () async {
      SharedPreferences.setMockInitialValues({'wellness_water_goal': 2});
      await WellnessService().init();
      for (int i = 0; i < 10; i++) {
        await WellnessService().addGlass();
      }
      expect(WellnessService().waterCount, 4); // 2 * 2
    });
  });

  group('WellnessService — saveWaterSettings', () {
    test('saves goal correctly', () async {
      await WellnessService().init();
      await WellnessService().saveWaterSettings(
        goal: 10, enabled: true, intervalHours: 2, startHour: 8, endHour: 22,
      );
      expect(WellnessService().waterGoal, 10);
    });

    test('ignores invalid intervalHours', () async {
      await WellnessService().init();
      await WellnessService().saveWaterSettings(
        goal: 8, enabled: true, intervalHours: 5, startHour: 8, endHour: 22,
      );
      expect(WellnessService().waterIntervalHours, 2); // unchanged default
    });

    test('ignores endHour <= startHour', () async {
      await WellnessService().init();
      await WellnessService().saveWaterSettings(
        goal: 8, enabled: true, intervalHours: 2, startHour: 22, endHour: 8,
      );
      expect(WellnessService().waterStartHour, 8); // unchanged
    });
  });
}
```

- [ ] **Step 2: Run tests to see them fail**

```bash
flutter test test/services/wellness_service_test.dart
```

Expected: FAIL — `wellness_service.dart` does not exist.

- [ ] **Step 3: Create WellnessService with water functionality**

Create `lib/services/wellness_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/vitamin_reminder.dart';
import 'notification_plugin.dart';

/// Manages daily water intake tracking and per-vitamin reminder notifications.
/// Persists all state in SharedPreferences. Extends [ChangeNotifier] so the
/// [WellnessScreen] can use [ListenableBuilder] for reactive rebuilds.
class WellnessService extends ChangeNotifier {
  static WellnessService _instance = WellnessService._();
  factory WellnessService() => _instance;
  WellnessService._();

  /// Testing only — resets the singleton so tests start clean.
  @visibleForTesting
  static void resetForTesting() {
    _instance = WellnessService._();
  }

  SharedPreferences? _prefs;

  // ── Internal state ────────────────────────────────────────────────────────

  int _waterGoal = 8;
  int _waterCount = 0;
  bool _waterEnabled = true;
  int _waterInterval = 2;
  int _waterStart = 8;
  int _waterEnd = 22;
  List<VitaminReminder> _vitamins = [];

  // Debounce timer for persistence after addGlass()
  Timer? _saveDebounce;

  // ── Public getters ────────────────────────────────────────────────────────

  int get waterGoal => _waterGoal;
  int get waterCount => _waterCount;
  bool get waterReminderEnabled => _waterEnabled;
  int get waterIntervalHours => _waterInterval;
  int get waterStartHour => _waterStart;
  int get waterEndHour => _waterEnd;
  bool get waterGoalReached => _waterCount >= _waterGoal;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadWaterState();
    _loadVitamins();
    await _createAndroidChannel();
    await _scheduleAllNotifications();
    notifyListeners();
  }

  void _loadWaterState() {
    _waterGoal = _prefs!.getInt('wellness_water_goal') ?? 8;
    _waterEnabled = _prefs!.getBool('wellness_water_reminder_enabled') ?? true;
    _waterInterval = _prefs!.getInt('wellness_water_interval_hours') ?? 2;
    _waterStart = _prefs!.getInt('wellness_water_start_hour') ?? 8;
    _waterEnd = _prefs!.getInt('wellness_water_end_hour') ?? 22;

    final today = _todayKey();
    _waterCount = _prefs!.getInt('wellness_water_count_$today') ?? 0;
  }

  void _loadVitamins() {
    final raw = _prefs!.getString('wellness_vitamins') ?? '[]';
    try {
      final list = json.decode(raw) as List<dynamic>;
      _vitamins = list
          .whereType<Map<String, dynamic>>()
          .map(VitaminReminder.fromJson)
          .toList();
    } catch (_) {
      _vitamins = [];
    }
  }

  // ── Water ─────────────────────────────────────────────────────────────────

  /// Increments the water count. UI updates immediately via [notifyListeners].
  /// If [waterGoalReached], notification cancellation happens immediately.
  /// SharedPreferences write + notification reschedule are debounced 500ms.
  Future<void> addGlass() async {
    if (_waterCount >= _waterGoal * 2) return;
    _waterCount++;
    notifyListeners();

    // Immediate: cancel water reminders the moment goal is reached
    if (waterGoalReached) {
      await _cancelWaterNotifications();
    }

    // Debounced: persist count + reschedule if not goal-reached
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _prefs?.setInt(
          'wellness_water_count_${_todayKey()}', _waterCount);
      if (!waterGoalReached) {
        await _scheduleWaterNotifications();
      }
    });
  }

  /// Saves water settings. Validates inputs; ignores invalid values.
  /// Always cancels and reschedules water notifications.
  Future<void> saveWaterSettings({
    required int goal,
    required bool enabled,
    required int intervalHours,
    required int startHour,
    required int endHour,
  }) async {
    // Validate
    if (![1, 2, 3, 4].contains(intervalHours)) return;
    if (endHour <= startHour) return;

    _waterGoal = goal.clamp(1, 20);
    _waterEnabled = enabled;
    _waterInterval = intervalHours;
    _waterStart = startHour;
    _waterEnd = endHour;

    await _prefs?.setInt('wellness_water_goal', _waterGoal);
    await _prefs?.setBool('wellness_water_reminder_enabled', _waterEnabled);
    await _prefs?.setInt('wellness_water_interval_hours', _waterInterval);
    await _prefs?.setInt('wellness_water_start_hour', _waterStart);
    await _prefs?.setInt('wellness_water_end_hour', _waterEnd);

    await _cancelWaterNotifications();
    if (_waterEnabled) await _scheduleWaterNotifications();

    notifyListeners();
  }

  // ── Vitamins ──────────────────────────────────────────────────────────────

  /// Returns vitamins with [takenToday] computed live from SharedPreferences.
  List<({VitaminReminder vitamin, bool takenToday})> get vitaminsWithStatus {
    final today = _todayKey();
    return _vitamins.map((v) {
      final taken =
          _prefs?.getBool('wellness_taken_${v.id}_$today') ?? false;
      return (vitamin: v, takenToday: taken);
    }).toList();
  }

  /// Adds a vitamin. Returns false (no-op) if already at 10 vitamins.
  Future<bool> addVitamin(String name, int hour, int minute) async {
    if (_vitamins.length >= 10) return false;

    final v = VitaminReminder(
      id: VitaminReminder.uniqueId(),
      name: name.trim(),
      hour: hour,
      minute: minute,
    );
    _vitamins.add(v);
    await _persistVitamins();
    await _scheduleVitaminNotification(v, _vitamins.length - 1);
    notifyListeners();
    return true;
  }

  /// Deletes a vitamin, cancels all vitamin notifications, re-indexes and
  /// reschedules remaining vitamins so ID = 300 + list position.
  Future<void> deleteVitamin(String id) async {
    _vitamins.removeWhere((v) => v.id == id);
    await _persistVitamins();
    await _cancelAllVitaminNotifications();
    for (int i = 0; i < _vitamins.length; i++) {
      await _scheduleVitaminNotification(_vitamins[i], i);
    }
    notifyListeners();
  }

  /// Marks a vitamin as taken (or untaken) for today.
  Future<void> markTaken(String id, bool taken) async {
    await _prefs?.setBool(
        'wellness_taken_${id}_${_todayKey()}', taken);
    notifyListeners();
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Future<void> _persistVitamins() async {
    final encoded =
        json.encode(_vitamins.map((v) => v.toJson()).toList());
    await _prefs?.setString('wellness_vitamins', encoded);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── Notification scheduling ───────────────────────────────────────────────

  Future<void> _createAndroidChannel() async {
    await notificationPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'wellness_reminders',
          'Wellness Reminders',
          description: 'Daily water and vitamin reminders',
          importance: Importance.defaultImportance,
        ));
  }

  Future<void> _scheduleAllNotifications() async {
    if (_waterEnabled) await _scheduleWaterNotifications();
    for (int i = 0; i < _vitamins.length; i++) {
      await _scheduleVitaminNotification(_vitamins[i], i);
    }
  }

  Future<void> _scheduleWaterNotifications() async {
    await _cancelWaterNotifications();
    if (!_waterEnabled) return;

    int slotIndex = 0;
    for (int h = _waterStart; h < _waterEnd; h += _waterInterval) {
      if (slotIndex > 22) break; // IDs 200-222 max 23 slots
      await _scheduleDaily(
        id: 200 + slotIndex,
        hour: h,
        minute: 0,
        title: '💧 Drink some water!',
        body: "Don't forget your daily water goal.",
      );
      slotIndex++;
    }
  }

  Future<void> _cancelWaterNotifications() async {
    for (int i = 0; i <= 22; i++) {
      await notificationPlugin.cancel(200 + i);
    }
  }

  Future<void> _scheduleVitaminNotification(
      VitaminReminder v, int index) async {
    await _scheduleDaily(
      id: 300 + index,
      hour: v.hour,
      minute: v.minute,
      title: '💊 Vitamin reminder',
      body: 'Time to take your ${v.name}.',
    );
  }

  Future<void> _cancelAllVitaminNotifications() async {
    for (int i = 0; i < 10; i++) {
      await notificationPlugin.cancel(300 + i);
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      final location = tz.local;
      final now = tz.TZDateTime.now(location);
      var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await notificationPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'wellness_reminders',
            'Wellness Reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('[Wellness] Failed to schedule notification $id: $e');
    }
  }
}
```

- [ ] **Step 4: Run the tests**

```bash
flutter test test/services/wellness_service_test.dart
```

Expected: PASS (all tests). If `SharedPreferences` mock fails, ensure `shared_preferences` is in dev deps or use `SharedPreferences.setMockInitialValues({})` as shown.

- [ ] **Step 5: Commit**

```bash
git add lib/services/wellness_service.dart \
        test/services/wellness_service_test.dart
git commit -m "feat: WellnessService with water tracking and vitamin management"
```

---

## Chunk 3: WellnessScreen UI

---

### Task 6: Create WellnessScreen — water section

**Files:**
- Create: `lib/screens/wellness_screen.dart`

**Context:** The screen uses `ListenableBuilder(listenable: WellnessService(), builder: ...)` so it rebuilds automatically on any `notifyListeners()` call. Design tokens: `AppColors.accentGreen` for water, `AppColors.accentCoral` for vitamins, `AppTheme.cardDecoration` for cards, `GoogleFonts.outfit` for all text. The screen is pushed via `Navigator.push` from `LogHubScreen`.

- [ ] **Step 1: Create the screen file with water section**

Create `lib/screens/wellness_screen.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/colors.dart';
import '../core/theme.dart';
import '../models/vitamin_reminder.dart';
import '../services/wellness_service.dart';

class WellnessScreen extends StatelessWidget {
  const WellnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WellnessService(),
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildSectionTitle('Water'),
                const SizedBox(height: 12),
                _buildWaterCard(context),
                const SizedBox(height: 28),
                _buildSectionTitle('Vitamins'),
                const SizedBox(height: 12),
                _buildVitaminSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wellness',
              style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text("Today's health habits",
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppColors.textSecondary)),
        ]),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  // ── Water ──────────────────────────────────────────────────────────────────

  Widget _buildWaterCard(BuildContext context) {
    final svc = WellnessService();
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _WaterProgressRing(count: svc.waterCount, goal: svc.waterGoal),
        const SizedBox(height: 16),
        _buildAddGlassButton(svc),
        const SizedBox(height: 16),
        _buildGlassIcons(svc),
        const SizedBox(height: 20),
        const Divider(color: AppColors.borderSubtle, height: 1),
        const SizedBox(height: 16),
        _buildWaterSettings(context, svc),
      ]),
    );
  }

  Widget _buildAddGlassButton(WellnessService svc) {
    final atCap = svc.waterCount >= svc.waterGoal * 2;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: atCap ? null : () => WellnessService().addGlass(),
        icon: Icon(
          svc.waterGoalReached
              ? Icons.check_circle_outline_rounded
              : Icons.add_rounded,
          size: 18,
        ),
        label: Text(
          svc.waterGoalReached ? 'Goal reached!' : 'Add a glass',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentGreen,
          disabledBackgroundColor: AppColors.accentGreen.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGlassIcons(WellnessService svc) {
    final filled = svc.waterCount.clamp(0, svc.waterGoal);
    final empty = (svc.waterGoal - filled).clamp(0, svc.waterGoal);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (int i = 0; i < filled; i++)
          const Icon(Icons.water_drop_rounded,
              size: 20, color: AppColors.accentGreen),
        for (int i = 0; i < empty; i++)
          Icon(Icons.water_drop_outlined,
              size: 20, color: AppColors.textDisabled),
      ],
    );
  }

  Widget _buildWaterSettings(BuildContext context, WellnessService svc) {
    return Column(children: [
      // Goal stepper
      _SettingsRow(
        label: 'Daily goal',
        child: Row(children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: svc.waterGoal > 1
                ? () => WellnessService().saveWaterSettings(
                      goal: svc.waterGoal - 1,
                      enabled: svc.waterReminderEnabled,
                      intervalHours: svc.waterIntervalHours,
                      startHour: svc.waterStartHour,
                      endHour: svc.waterEndHour,
                    )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${svc.waterGoal}',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: svc.waterGoal < 20
                ? () => WellnessService().saveWaterSettings(
                      goal: svc.waterGoal + 1,
                      enabled: svc.waterReminderEnabled,
                      intervalHours: svc.waterIntervalHours,
                      startHour: svc.waterStartHour,
                      endHour: svc.waterEndHour,
                    )
                : null,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // Interval dropdown
      _SettingsRow(
        label: 'Remind every',
        child: DropdownButton<int>(
          value: svc.waterIntervalHours,
          underline: const SizedBox(),
          style: GoogleFonts.outfit(
              fontSize: 14, color: AppColors.textPrimary),
          items: const [
            DropdownMenuItem(value: 1, child: Text('1 hour')),
            DropdownMenuItem(value: 2, child: Text('2 hours')),
            DropdownMenuItem(value: 3, child: Text('3 hours')),
            DropdownMenuItem(value: 4, child: Text('4 hours')),
          ],
          onChanged: (v) {
            if (v == null) return;
            WellnessService().saveWaterSettings(
              goal: svc.waterGoal,
              enabled: svc.waterReminderEnabled,
              intervalHours: v,
              startHour: svc.waterStartHour,
              endHour: svc.waterEndHour,
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      // Active hours
      _SettingsRow(
        label: 'Active hours',
        child: Row(children: [
          _TimeChip(
            hour: svc.waterStartHour,
            minute: 0,
            onPick: (tod) => WellnessService().saveWaterSettings(
              goal: svc.waterGoal,
              enabled: svc.waterReminderEnabled,
              intervalHours: svc.waterIntervalHours,
              startHour: tod.hour,
              endHour: svc.waterEndHour,
            ),
            context: context,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('→',
                style: GoogleFonts.outfit(color: AppColors.textTertiary)),
          ),
          _TimeChip(
            hour: svc.waterEndHour,
            minute: 0,
            onPick: (tod) => WellnessService().saveWaterSettings(
              goal: svc.waterGoal,
              enabled: svc.waterReminderEnabled,
              intervalHours: svc.waterIntervalHours,
              startHour: svc.waterStartHour,
              endHour: tod.hour,
            ),
            context: context,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // Reminders toggle
      _SettingsRow(
        label: 'Reminders',
        child: Switch(
          value: svc.waterReminderEnabled,
          activeColor: AppColors.accentGreen,
          onChanged: (v) => WellnessService().saveWaterSettings(
            goal: svc.waterGoal,
            enabled: v,
            intervalHours: svc.waterIntervalHours,
            startHour: svc.waterStartHour,
            endHour: svc.waterEndHour,
          ),
        ),
      ),
    ]);
  }

  // ── Vitamins ───────────────────────────────────────────────────────────────

  Widget _buildVitaminSection(BuildContext context) {
    final svc = WellnessService();
    final vitamins = svc.vitaminsWithStatus;

    return Column(children: [
      ...vitamins.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _VitaminCard(
              vitamin: entry.vitamin,
              takenToday: entry.takenToday,
            ),
          )),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: Tooltip(
          message: vitamins.length >= 10 ? 'Maximum 10 vitamins reached' : '',
          child: FilledButton.icon(
            onPressed: vitamins.length >= 10
                ? null
                : () => _showAddVitaminSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add vitamin',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              disabledBackgroundColor:
                  AppColors.accentCoral.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    ]);
  }

  void _showAddVitaminSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddVitaminSheet(),
    );
  }
}

// ── Water progress ring ────────────────────────────────────────────────────────

class _WaterProgressRing extends StatelessWidget {
  final int count;
  final int goal;

  const _WaterProgressRing({required this.count, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (count / goal).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: const Size(120, 120),
          painter: _RingPainter(progress: progress),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$count',
              style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text('/ $goal',
              style: GoogleFonts.outfit(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = AppColors.borderSubtle
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppColors.accentGreen
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Vitamin card ────────────────────────────────────────────────────────────────

class _VitaminCard extends StatelessWidget {
  final VitaminReminder vitamin;
  final bool takenToday;

  const _VitaminCard({required this.vitamin, required this.takenToday});

  @override
  Widget build(BuildContext context) {
    final timeStr = TimeOfDay(hour: vitamin.hour, minute: vitamin.minute)
        .format(context);
    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentCoral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication_outlined,
                color: AppColors.accentCoral, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vitamin.name,
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(timeStr,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textTertiary)),
          ])),
          takenToday
              ? FilledButton(
                  onPressed: () =>
                      WellnessService().markTaken(vitamin.id, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text('✓ Taken',
                      style: GoogleFonts.outfit(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                )
              : OutlinedButton(
                  onPressed: () =>
                      WellnessService().markTaken(vitamin.id, true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accentCoral),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text('Take',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentCoral)),
                ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete vitamin?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
          "This will remove '${vitamin.name}' and cancel its daily reminder.",
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            onPressed: () {
              WellnessService().deleteVitamin(vitamin.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentRed),
            child: Text('Delete', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }
}

// ── Add vitamin bottom sheet ────────────────────────────────────────────────────

class _AddVitaminSheet extends StatefulWidget {
  const _AddVitaminSheet();

  @override
  State<_AddVitaminSheet> createState() => _AddVitaminSheetState();
}

class _AddVitaminSheetState extends State<_AddVitaminSheet> {
  final _nameController = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Add vitamin',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          maxLength: 30,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Vitamin name',
            labelStyle: GoogleFonts.outfit(),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          style: GoogleFonts.outfit(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
                context: context, initialTime: _time);
            if (picked != null) setState(() => _time = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.alarm_rounded,
                  color: AppColors.textTertiary, size: 20),
              const SizedBox(width: 12),
              Text('Reminder time: ${_time.format(context)}',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textPrimary)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave ? _save : null,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentCoral,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text('Save',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    await WellnessService().addVitamin(
      _nameController.text.trim(),
      _time.hour,
      _time.minute,
    );
    if (mounted) Navigator.pop(context);
  }
}

// ── Shared small widgets ────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 14, color: AppColors.textSecondary)),
        child,
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.accentGreen.withValues(alpha: 0.12)
              : AppColors.borderSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null
                ? AppColors.accentGreen
                : AppColors.textDisabled),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final int hour;
  final int minute;
  final void Function(TimeOfDay) onPick;
  final BuildContext context;

  const _TimeChip({
    required this.hour,
    required this.minute,
    required this.onPick,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final display =
        TimeOfDay(hour: hour, minute: minute).format(context);
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: minute));
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(display,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.accentGreen)),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze to check for errors**

```bash
cd "C:/Users/afarhat/personal/New folder/cgm_app"
flutter analyze lib/screens/wellness_screen.dart
```

Expected: No errors. Fix any reported issues before proceeding.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/wellness_screen.dart
git commit -m "feat: WellnessScreen UI with water and vitamin sections"
```

---

## Chunk 4: Integration — main.dart, log_hub_screen entry point, AppColors

---

### Task 7: Update main.dart — timezone init + WellnessService

**Files:**
- Modify: `lib/main.dart`

**Context:** The current `main.dart` init order is: `UserProfileService → OfflineCacheService → AlertService → JugglucoService.start()`. We need to insert `initNotificationPlugin()` + timezone init before `AlertService.init()`, and `WellnessService.init()` after it.

- [ ] **Step 1: Update the imports in main.dart**

Add these imports at the top of `lib/main.dart`:

```dart
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'services/notification_plugin.dart';
import 'services/wellness_service.dart';
```

- [ ] **Step 2: Replace the init block in main()**

Replace the current init block (the three `await` calls + `JugglucoService` call) with:

```dart
  // 1. SharedPreferences-backed services
  await UserProfileService().init();
  await OfflineCacheService().init();

  // 2. Notification plugin — initialize exactly once before any service uses it
  await initNotificationPlugin();

  // 3. Timezone — must be initialized before WellnessService schedules notifications
  tz.initializeTimeZones();
  final tzName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzName));

  // 4. Services that send notifications
  await AlertService().init();
  await WellnessService().init();

  // 5. Juggluco CGM polling
  JugglucoService().start();
```

- [ ] **Step 3: Verify the app builds**

```bash
flutter analyze lib/main.dart
```

Expected: No errors.

---

### Task 8: Verify AppColors has needed constants

**Files:**
- Possibly modify: `lib/core/colors.dart`

**Context:** `WellnessScreen` uses `AppColors.accentCoralLight` and `AppColors.textDisabled`. Check if they exist.

- [ ] **Step 1: Check which constants exist**

```bash
grep -n "accentCoralLight\|textDisabled\|accentGreenLight" "C:/Users/afarhat/personal/New folder/cgm_app/lib/core/colors.dart"
```

- [ ] **Step 2: Add any missing constants**

Open `lib/core/colors.dart`. If `accentCoralLight` is missing, add it alongside the other accent colors:

```dart
static const Color accentCoralLight = Color(0xFFF5E6DD);
```

If `textDisabled` is missing, add it in the text color group:

```dart
static const Color textDisabled = Color(0xFFBBBBBB);
```

If `accentGreenLight` is missing:

```dart
static const Color accentGreenLight = Color(0xFFD6EDE1);
```

- [ ] **Step 3: Run analyze again**

```bash
flutter analyze lib/screens/wellness_screen.dart lib/core/colors.dart
```

Expected: No errors.

---

### Task 9: Add Wellness entry card to LogHubScreen

**Files:**
- Modify: `lib/screens/log_hub_screen.dart`

**Context:** The `_HypoCard` is a row-style card. We add a similar card below it that pushes `WellnessScreen` on tap.

- [ ] **Step 1: Add import for WellnessScreen**

At the top of `lib/screens/log_hub_screen.dart`, add:

```dart
import 'wellness_screen.dart';
```

- [ ] **Step 2: Add the Wellness card in the build method**

Locate the line `_HypoCard(onTap: () => _navigate(const LogHypoScreen())),` and add directly after it:

```dart
              const SizedBox(height: 12),
              _WellnessCard(onTap: () => _navigate(const WellnessScreen())),
```

- [ ] **Step 3: Add the _WellnessCard widget class**

At the bottom of `log_hub_screen.dart` (after `_HypoCard`), add:

```dart
class _WellnessCard extends StatelessWidget {
  final VoidCallback onTap;
  const _WellnessCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration
            .copyWith(borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.spa_outlined,
                  color: AppColors.accentGreen, size: 24)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Wellness',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Water & vitamins tracker',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 20),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze lib/screens/log_hub_screen.dart
```

Expected: No errors.

---

### Task 10: Full build + smoke test on device

- [ ] **Step 1: Run all unit tests**

```bash
cd "C:/Users/afarhat/personal/New folder/cgm_app"
flutter test
```

Expected: All tests pass.

- [ ] **Step 2: Build the app**

```bash
flutter build apk --debug
```

Expected: Build succeeded with no errors.

- [ ] **Step 3: Manual smoke test on device**

Run the app and verify:
1. Log tab → Wellness card visible below "Hypo Event"
2. Tap Wellness → WellnessScreen opens
3. Water ring shows 0/8 — tap "+ Add a glass" → count increases, ring fills
4. Tap 8 times → ring shows full, button shows "✓ Goal reached!"
5. Settings: change goal to 6 → ring updates. Change interval → saved.
6. Vitamins section: tap "+ Add vitamin" → sheet opens → enter name + time → Save
7. Vitamin card appears with "Take" button → tap → shows "✓ Taken"
8. Long-press vitamin → confirm delete → vitamin removed
9. Background notification received at the scheduled time (may need to wait)

- [ ] **Step 4: Final commit**

```bash
git add lib/main.dart \
        lib/core/colors.dart \
        lib/screens/log_hub_screen.dart
git commit -m "feat: wire up WellnessService init and LogHub entry card"
```

---

## Summary of all files

| Action | File |
|--------|------|
| CREATE | `lib/services/notification_plugin.dart` |
| CREATE | `lib/models/vitamin_reminder.dart` |
| CREATE | `lib/services/wellness_service.dart` |
| CREATE | `lib/screens/wellness_screen.dart` |
| CREATE | `test/services/notification_plugin_test.dart` |
| CREATE | `test/models/vitamin_reminder_test.dart` |
| CREATE | `test/services/wellness_service_test.dart` |
| MODIFY | `lib/services/alert_service.dart` (use shared plugin) |
| MODIFY | `lib/main.dart` (timezone + WellnessService init) |
| MODIFY | `lib/core/colors.dart` (add missing color constants if needed) |
| MODIFY | `lib/screens/log_hub_screen.dart` (add Wellness card) |
| MODIFY | `pubspec.yaml` (add timezone + flutter_timezone) |
