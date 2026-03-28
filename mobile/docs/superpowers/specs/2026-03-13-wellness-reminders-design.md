# Wellness Reminders — Design Spec
**Date:** 2026-03-13
**Status:** Approved

---

## Overview

Add water intake tracking (goal-based, tap-to-log) and per-vitamin daily reminders to the CGM app. Accessible via a new "Wellness" card in the existing Log Hub screen. Notifications via the existing `flutter_local_notifications` plugin (shared singleton) plus `timezone` and `flutter_timezone` packages.

---

## Architecture

### New files
| File | Purpose |
|------|---------|
| `lib/services/notification_plugin.dart` | Top-level shared `FlutterLocalNotificationsPlugin` singleton + single `initialize()` call |
| `lib/models/vitamin_reminder.dart` | Data class: id, name, hour, minute (no takenToday field) |
| `lib/services/wellness_service.dart` | Singleton `ChangeNotifier`: water/vitamin state, persistence, notification scheduling |
| `lib/screens/wellness_screen.dart` | Full UI: water progress ring + vitamin checklist |

### Modified files
| File | Change |
|------|--------|
| `lib/services/alert_service.dart` | Remove private `_notifications` field; import and use shared `notificationPlugin` from `notification_plugin.dart` |
| `lib/screens/log_hub_screen.dart` | Add "Wellness" entry card below the Hypo card |
| `lib/main.dart` | Add tz init steps + `WellnessService().init()` (see full order below) |
| `pubspec.yaml` | Add `timezone: ^0.9.0` and `flutter_timezone: ^1.0.4` |

---

## notification_plugin.dart

This file owns the single plugin instance and calls `initialize()` exactly once. Both `AlertService` and `WellnessService` import `notificationPlugin` from here — neither instantiates its own.

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

---

## Full main.dart Initialization Order

```dart
// 1. SharedPreferences-backed services (no dependencies)
await UserProfileService().init();
await OfflineCacheService().init();

// 2. Notification plugin — must be initialized before any service that sends notifications
await initNotificationPlugin();

// 3. Timezone — must be initialized before any zonedSchedule call
tz.initializeTimeZones();
final tzName = await FlutterTimezone.getLocalTimezone();
tz.setLocalLocation(tz.getLocation(tzName));

// 4. Services that use notifications
await AlertService().init();
await WellnessService().init();

// 5. Juggluco polling
JugglucoService().start();
```

---

## Data Model

### VitaminReminder
```dart
class VitaminReminder {
  final String id;    // "vit_<epochMs>_<counter>", counter is a static int incremented per call,
                      // guaranteeing uniqueness even if two vitamins are added in the same millisecond
  final String name;  // "Vitamin D" etc., max 30 chars
  final int hour;     // 0–23
  final int minute;   // 0–59

  Map<String, dynamic> toJson();
  factory VitaminReminder.fromJson(Map<String, dynamic> json);
}
```

`takenToday` is **NOT** a model field. It is computed at read time from the SharedPreferences key `wellness_taken_<id>_YYYY-MM-DD` for today's date. This avoids stale state after midnight restarts.

### SharedPreferences keys

| Key | Type | Default | Notes |
|-----|------|---------|-------|
| `wellness_water_goal` | int | 8 | Min 1, max 20 |
| `wellness_water_count_YYYY-MM-DD` | int | 0 | Date-scoped; no explicit reset needed |
| `wellness_water_reminder_enabled` | bool | true | |
| `wellness_water_interval_hours` | int | 2 | Valid values: 1, 2, 3, 4 |
| `wellness_water_start_hour` | int | 8 | 0–23 |
| `wellness_water_end_hour` | int | 22 | 0–23, must be > start_hour |
| `wellness_vitamins` | String | `'[]'` | JSON-encoded list |
| `wellness_taken_<id>_YYYY-MM-DD` | bool | — | Per-vitamin, per-day taken flag |

**No `wellness_last_date` key.** Stale date-keyed entries from previous days are left in SharedPreferences (harmless volume). Deleted vitamins' taken keys are not swept (accepted orphan).

---

## WellnessService

`WellnessService extends ChangeNotifier`. Uses the same Dart factory-constructor singleton pattern as `AlertService` and `OfflineCacheService`:
```dart
static final WellnessService _instance = WellnessService._();
factory WellnessService() => _instance;
WellnessService._();
```
`WellnessService()` always returns the same instance. After each mutation it calls `notifyListeners()` so `WellnessScreen` (wrapped in `ListenableBuilder`) rebuilds automatically.

```dart
class WellnessService extends ChangeNotifier {
  static final WellnessService _instance = WellnessService._();
  factory WellnessService() => _instance;

  Future<void> init();    // load prefs, schedule notifications, notifyListeners

  // ── Water ──────────────────────────────────────────────────────
  int get waterGoal;
  int get waterCount;               // today
  bool get waterReminderEnabled;
  int get waterIntervalHours;       // always one of: 1, 2, 3, 4
  int get waterStartHour;
  int get waterEndHour;
  bool get waterGoalReached;        // waterCount >= waterGoal

  /// Increments count by 1. Immediately calls notifyListeners() so UI updates.
  /// Notification cancellation (if goal reached) executes immediately — NOT debounced.
  /// SharedPreferences write and notification rescheduling are debounced 500ms.
  /// Cap: count cannot exceed waterGoal * 2 (ignores calls above cap).
  Future<void> addGlass();

  /// Saves water settings to SharedPreferences.
  /// goal clamped to 1–20. intervalHours must be 1/2/3/4 (else ignored).
  /// endHour must be > startHour (else ignored).
  /// Then: cancels water notification IDs 200–222, reschedules if enabled.
  /// Calls notifyListeners().
  Future<void> saveWaterSettings({
    required int goal,
    required bool enabled,
    required int intervalHours,
    required int startHour,
    required int endHour,
  });

  // ── Vitamins ────────────────────────────────────────────────────

  /// Returns vitamins with takenToday computed from SharedPreferences (today's date key).
  /// O(vitamins.length) SharedPreferences reads — acceptable for ≤10 items.
  List<({VitaminReminder vitamin, bool takenToday})> get vitaminsWithStatus;

  /// Returns false and no-ops if vitamins.length >= 10.
  /// On success: appends, persists, schedules notification at next available index,
  /// notifyListeners, returns true.
  Future<bool> addVitamin(String name, int hour, int minute);

  /// Cancels ALL vitamin notification IDs 300–309 unconditionally.
  /// Removes the vitamin from the in-memory list.
  /// Re-indexes: the vitamin now at list position i receives notification ID 300+i.
  /// Reschedules notifications for all remaining vitamins at their new IDs.
  /// Persists updated list. Calls notifyListeners.
  Future<void> deleteVitamin(String id);

  /// Writes wellness_taken_<id>_YYYY-MM-DD = taken. notifyListeners.
  /// Idempotent: writing the same value twice is harmless.
  /// Always uses today's date; no date parameter.
  Future<void> markTaken(String id, bool taken);
}
```

### UI wiring
`WellnessScreen` uses `ListenableBuilder(listenable: WellnessService(), builder: ...)` as its top-level widget so the entire screen rebuilds on any `notifyListeners()` call from the service.

---

## Notification Scheduling

### Android channel creation
`WellnessService.init()` creates the wellness channel:
```dart
await notificationPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(const AndroidNotificationChannel(
      'wellness_reminders',
      'Wellness Reminders',
      description: 'Daily water and vitamin reminders',
      importance: Importance.defaultImportance,
    ));
```

### Water notification IDs: 200–223 (24 IDs)

**Slot definition:** a notification fires at `startHour + n * intervalHours` for n = 0, 1, 2, ... while the time is **strictly less than** `endHour`. The end hour is exclusive (no notification fires at or after endHour).

**Maximum possible slots:** with interval = 1h, startHour = 0, endHour = 23 → slots at 0,1,...,22 = **23 slots**. ID range 200–222 covers this. **IDs 200–222 (23 IDs) are sufficient.** The previous concern about 24 slots was incorrect: endHour is exclusive, so hour 23 is never used with endHour=23.

With defaults (start=8, end=22, interval=2): slots at 8,10,12,14,16,18,20 = 7 slots.
With interval=1h, start=8, end=22: slots at 8,9,...,21 = 14 slots. Well within 23.

**Scheduling:**
- `_scheduleWaterNotifications()`: cancel IDs 200–222 unconditionally, then for each slot fire:
  ```
  Title: "💧 Drink some water!"
  Body:  "Don't forget your daily water goal."
  AndroidNotificationDetails(channelId: 'wellness_reminders', importance: Importance.defaultImportance)
  zonedSchedule with matchDateTimeComponents: DateTimeComponents.time
  ```
- On `addGlass()` when `waterGoalReached`: call `notificationPlugin.cancel(id)` for all IDs 200–222 unconditionally (cancelling an already-fired or non-existent notification is a no-op).
- On `saveWaterSettings()`: cancel 200–222, reschedule if enabled.

### Vitamin notification IDs: 300–309

Vitamin at list index `i` always uses ID `300 + i`.

**On `addVitamin()`:** vitamin is appended to end of list (index = list.length before append). Notification scheduled at `300 + new_index`.

**On `deleteVitamin()`:**
1. Cancel all IDs 300–309 unconditionally.
2. Remove vitamin from list.
3. Re-index remaining vitamins (list positions 0–N-1).
4. Schedule new notifications for each remaining vitamin at its new index ID.
5. Persist updated list.

This ensures no ID gaps and no stale notifications. Re-indexing is safe because the full cancel precedes scheduling.

**Notification content:**
```
Title: "💊 Vitamin reminder"
Body:  "Time to take your [name]."
zonedSchedule with matchDateTimeComponents: DateTimeComponents.time
```

---

## UI — WellnessScreen

### Entry point
New card in `LogHubScreen` below the Hypo card:
```
[Icons.spa_outlined, color accentGreen, bg accentGreenLight]  Wellness          ›
                                                               Water & vitamins tracker
```

### WellnessScreen

Top-level: `ListenableBuilder(listenable: WellnessService(), builder: ...)` inside `Scaffold`.

```
Header: "Wellness"  /  "Today's health habits"

──── Water ────────────────────────────────────────────────────

Progress ring:
  Width/Height: 120px  |  Stroke: 10px
  Track color: AppColors.borderSubtle
  Fill color: AppColors.accentGreen (both incomplete and complete states)
  Progress value: (waterCount / waterGoal).clamp(0.0, 1.0)
  Center: Text "${waterCount}\n/ ${waterGoal}" — count in 28sp bold, "/ goal" in 13sp secondary

Add glass button (FilledButton):
  - Normal:   "+ Add a glass"
  - Reached:  "✓ Goal reached!"  (still tappable up to goal*2 cap)
  - Disabled: count >= waterGoal * 2

Glass icon row:
  min(waterCount, waterGoal) × Icons.water_drop_rounded (accentGreen, size 18)
  max(waterGoal - waterCount, 0) × Icons.water_drop_outlined (textDisabled, size 18)
  Row wraps if goal > 10 (using Wrap widget)

Settings card (AppTheme.cardDecoration, padding 16):
  Row: "Daily goal"      [−] {waterGoal} [+]       (min 1, max 20)
  Row: "Remind every"    [DropdownButton: "1 hour" | "2 hours" | "3 hours" | "4 hours"]
  Row: "From"            [GestureDetector: HH:MM] → [GestureDetector: HH:MM]  (TimeOfDay pickers)
  Row: "Reminders"       [Switch]
  All rows save immediately on change (no Save button)

──── Vitamins ──────────────────────────────────────────────────

Section header: "Vitamins"

Per vitamin — ListTile-style card (AppTheme.cardDecoration, margin bottom 8):
  Leading: Container(48×48, accentCoralLight bg, Icons.medication_outlined, accentCoral)
  Title: vitamin.name  (Outfit 15sp semibold)
  Subtitle: "HH:MM AM/PM"  (Outfit 13sp textTertiary)
  Trailing: OutlinedButton "Take" / FilledButton "✓ Taken" (toggles markTaken)
  Long-press → showDialog:
    Title: "Delete vitamin?"
    Content: "This will remove '${name}' and cancel its daily reminder."
    Actions: [Cancel] [Delete]  (Delete calls deleteVitamin)

Add vitamin button:
  - vitamins.length < 10: FilledButton "+ Add vitamin"
  - vitamins.length >= 10: FilledButton disabled + Tooltip "Maximum 10 vitamins reached"

Add vitamin bottom sheet (showModalBottomSheet, isScrollControlled: true):
  TextField: label "Vitamin name", maxLength 30, autofocus true
  Row: "Reminder time:" [GestureDetector showing HH:MM AM/PM] → showTimePicker
  FilledButton "Save" — disabled until name.trim().isNotEmpty
  On save: calls addVitamin(), Navigator.pop()
```

---

## Error Handling
- Notification scheduling failure: caught, debug-printed, app continues
- SharedPreferences read failure: use defaults for all water settings, empty list for vitamins
- Malformed `wellness_vitamins` JSON: reset to `[]`, debug-print error
- `addVitamin()` at capacity: returns `false`, UI button already disabled
- Invalid `saveWaterSettings` inputs (bad interval, endHour ≤ startHour): silently ignore call

---

## Out of Scope
- Historical water/vitamin tracking or trends
- Syncing wellness data to the remote API
- Notification tap → deep link into WellnessScreen
- More than 10 vitamins
