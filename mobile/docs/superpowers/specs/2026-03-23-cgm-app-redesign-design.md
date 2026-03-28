# CGM App Redesign — Design Spec
**Date:** 2026-03-23
**Approach:** Screen-by-screen replacement (Option B) — services intact, UI layer fully replaced

---

## 1. Goal

Rebuild the GlucoCoach Flutter app UI to match the Stitch design (dark glass-morphism theme, teal primary) while wiring all screens to the updated API that now includes JWT authentication, a dashboard endpoint, full CRUD for bolus/basal/hypo, and new meal logging + correlation endpoints.

---

## 2. Architecture

### 2.1 New: AuthService
`lib/services/auth_service.dart` — singleton, JWT lifecycle manager.

| Method | Endpoint | Notes |
|--------|----------|-------|
| `init()` | — | Loads stored JWT from SharedPreferences; must be called with `await` in `main()` before `isLoggedIn` is read |
| `register(email, password, {height, weight, glucoseUnit})` | `POST /api/v1/auth/register` | Calls `login()` on success to store token |
| `login(email, password)` | `POST /api/v1/auth/token` | OAuth2 form body (`application/x-www-form-urlencoded`); stores JWT in SharedPreferences under key `auth_token` |
| `logout()` | — | Clears `auth_token` from SharedPreferences |
| `getToken()` | — | Returns stored JWT string or null |
| `isLoggedIn` | — | Bool getter: `getToken() != null` |
| `getMe()` | `GET /api/v1/auth/me` | Returns `UserResponse {id, email}` |
| `updateMe({height, weight, glucoseUnit})` | `PATCH /api/v1/auth/me` | Updates height/weight/glucose_unit on server |

Token stored under SharedPreferences key: `auth_token`.
No refresh token flow — user re-authenticates when token expires (401 triggers logout + redirect).

**`glucose_unit` persistence:** Stored in both the API (via `PATCH /auth/me`) and locally in `UserProfileService` (key `glucose_unit`, read for offline display). On profile load, the value from `PATCH /auth/me` response takes precedence and overwrites the local copy.

### 2.2 Updated: ApiService

**Token injection** — add `_headers` getter:
```dart
Map<String,String> get _headers => {
  'Content-Type': 'application/json',
  if (AuthService.instance.getToken() != null)
    'Authorization': 'Bearer ${AuthService.instance.getToken()}',
};
```

**401 global handling** — `MaterialApp` in `main.dart` is given a `GlobalKey<NavigatorState>` (named `navigatorKey`). `ApiService` holds a reference to this key. On any 401 response:
```dart
AuthService.instance.logout();
navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
```
This applies to all requests including `OfflineCacheService.syncPending()` — an expired token during sync will log the user out.

**New methods added to ApiService:**
- `getDashboard()` → `GET /api/v1/dashboard` → `DashboardResponse`
- `getBolusHistory()` → `GET /api/v1/bolus` → `List<BolusEntry>`
- `getBasalHistory()` → `GET /api/v1/basal` → `List<BasalEntry>`
- `getHypoHistory({int limit = 20})` → `GET /api/v1/hypo` → `List<HypoEntry>`
- `deleteHypo(String id)` → `DELETE /api/v1/hypo/{id}` — called from swipe-to-delete on `HypoTrackerScreen` event list

### 2.3 DashboardResponse Schema
```
GET /api/v1/dashboard → DashboardResponse {
  basal_units_today: number
  bolus_units_today: number
  total_insulin_today: number
  meals_today: integer
  bolus_logs_today: integer
  hypo_events_last_7d: integer
  basal_logs_last_7d: integer
  bolus_logs_last_7d: integer
  last_basal: LastDose? { units, timestamp, insulin_type }
  last_bolus: LastDose? { units, timestamp }
}
```
HomeScreen uses `bolus_units_today`, `basal_units_today`, `total_insulin_today`, `meals_today`, `last_bolus`, `last_basal` for the quick stats. TIR gauge comes from `GET /api/v1/glucose/report?days=7`.

### 2.4 New: MealService
`lib/services/meal_service.dart` — wraps meal endpoints.

| Method | Endpoint |
|--------|----------|
| `logMeal(MealCreate)` | `POST /api/v1/meal/` |
| `getMeals()` | `GET /api/v1/meal/` |
| `getCorrelation()` | `GET /api/v1/meal/correlation` → `List<MealCorrelation>` |
| `deleteMeal(String id)` | `DELETE /api/v1/meal/{id}` |

`MealCreate` fields: `meal_type` (low_gi/medium_gi/high_gi, required), `carbs_g` (`number?`, 0–500), `description` (`string?`, max 500 chars), `glucose_before` (`number?`).

`MealCorrelation` fields: `meal_type: String`, `avg_spike: number?`, `sample_count: integer`.

Meal logging is online-only — no offline queue. `OfflineCacheService` is not involved.

### 2.5 Kept Unchanged
- `JugglucoService` — CGM glucose stream polling
- `AlertService` — local notifications for hypo/high alerts
- `OfflineCacheService` — offline queue for bolus/basal (not meals)
- `UserProfileService` — alert thresholds, Juggluco toggle, CGM URL, local name, glucose_unit cache

### 2.6 Removed
- `WellnessService` — removed along with `WellnessScreen`. Its `init()` call is removed from `main.dart`. Scheduled vitamin/water reminders will cease after the upgrade. This is intentional.

### 2.7 App Startup Flow
```
main()
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ await AuthService.instance.init()       ← loads JWT from SharedPreferences
  ├─ await UserProfileService.instance.init()
  ├─ await OfflineCacheService.instance.init()
  ├─ await AlertService.instance.init()
  └─ runApp(GlucoApp(isLoggedIn: AuthService.instance.isLoggedIn))

GlucoApp:
  MaterialApp(
    navigatorKey: navigatorKey,              ← GlobalKey<NavigatorState>
    initialRoute: isLoggedIn ? '/home' : '/login',
    ...
  )
```

---

## 3. Design System

### 3.1 Colors (`lib/core/colors.dart` — full replacement)
```dart
primary      = Color(0xFF00BFB3)
bgDark       = Color(0xFF1E2130)
surfaceGlass = Color(0x42262B3D)   // rgba(38,43,61,0.65)
surfaceSolid = Color(0xFF262B3D)
inRange      = Color(0xFF2ECC71)
high         = Color(0xFFF0A500)
low          = Color(0xFFFF6B6B)
textMain     = Color(0xFFF8F9FA)
textMuted    = Color(0xFF9CA3AF)
borderGlass  = Color(0x14FFFFFF)   // rgba(255,255,255,0.08)
```

### 3.2 Theme (`lib/core/theme.dart`)
- `scaffoldBackgroundColor`: `bgDark`
- Font: **Spline Sans** via `google_fonts` (replaces Outfit); weights 400/500/600/700. Network font fetching is acceptable — the app requires internet for API calls anyway.
- `glassDecoration` helper: `BoxDecoration` with `surfaceGlass`, `borderGlass` border, `BorderRadius.circular(16)`, used with `BackdropFilter(filter: ImageFilter.blur(sigmaX:12, sigmaY:12))`
- Dark `ThemeData` throughout — no light mode

### 3.3 New Shared Widgets
- **`GlassCard`** (`lib/widgets/glass_card.dart`) — wraps child in glass decoration with `ClipRRect` + `BackdropFilter`
- **`FloatingNavBar`** (`lib/widgets/floating_nav_bar.dart`) — custom bottom nav pill widget, fixed position, 5 items
- **`PrimaryButton`** (`lib/widgets/primary_button.dart`) — teal full-width button with `boxShadow` glow (replaces existing)
- **`GlassTextField`** (`lib/widgets/glass_text_field.dart`) — `surfaceSolid` background input with `primary` focus ring

---

## 4. Navigation

### 4.1 Tab Structure (MainScreen)
| Index | Icon | Destination |
|-------|------|-------------|
| 0 | `house` (filled when active) | `HomeScreen` |
| 1 | `monitoring` | `StatsScreen` |
| 2 | `add` (teal FAB, never "active") | `LogBottomSheet` modal |
| 3 | `insights` (filled when active) | `InsightsScreen` |
| 4 | `verified_user` (filled when active) | `ProfileScreen` |

### 4.2 LogBottomSheet
Glass modal sheet (`showModalBottomSheet`) with 4 action tiles:
- **Log Bolus** (vaccines icon) → `Navigator.push` to `LogBolusScreen`
- **Log Basal** (medication icon) → `LogBasalScreen`
- **Log Meal** (restaurant icon) → `LogMealScreen`
- **Log Hypo** (water_drop icon) → `LogHypoFormScreen` (the entry form directly)

### 4.3 Hypo Screens Disambiguation
| File | Class | Purpose |
|------|-------|---------|
| `lib/screens/hypo_tracker_screen.dart` | `HypoTrackerScreen` | List view: summary stats + event history |
| `lib/screens/log_hypo_screen.dart` | `LogHypoFormScreen` | Form: log a new hypo event |

The current `log_hypo_screen.dart` becomes `LogHypoFormScreen`. A new `hypo_tracker_screen.dart` is created for the list view. This avoids any file naming collision.

---

## 5. Screens

### 5.1 LoginScreen (`lib/screens/login_screen.dart`) — NEW
- GlucoCoach logo: `water_drop` icon in teal circle + 48px bold title with glow effect
- Email field (mail icon prefix), Password field (lock icon prefix, visibility toggle)
- Forgot password link (taps show a "Coming soon" SnackBar)
- Sign In button → `AuthService.login()` → on success navigate to `/home`; on error show SnackBar with server message
- "Create account" link → `RegisterScreen`

### 5.2 RegisterScreen (`lib/screens/register_screen.dart`) — NEW
- Back button header
- "Create Account" h1 + "Let's personalize your experience" subtitle
- Full Name field → stored locally in `UserProfileService` (not sent to API). **Note:** name is device-local only — it will not survive a reinstall or login on a new device.
- Email + Password fields
- Glucose Unit toggle pill (mg/dL selected by default / mmol/L)
- Height + Weight side-by-side inputs with cm/kg suffixes
- Sticky bottom CTA → `AuthService.register()` → on success navigate to `/home`
- "Already have an account? Sign In" link → back to `LoginScreen`

### 5.3 HomeScreen (`lib/screens/home_screen.dart`) — REBUILT
**Data sources:**
- `GET /api/v1/dashboard` → `DashboardResponse` (insulin totals, meal count, last doses)
- `GET /api/v1/glucose/report?days=7` → TIR %, avg glucose, GMI, CV, dawn phenomenon
- `JugglucoService` stream → live glucose reading (if Juggluco enabled)

**Note:** The existing bolus advisor card (`_buildBolusAdvisorCard`) is removed entirely. `BolusAdvisorScreen` no longer exists.

**Layout:**
1. Header: teal gradient avatar circle with initials (from local name), "Good [time], [Name]" greeting, notification bell
2. **Today's Control** `GlassCard`: circular TIR gauge (`CustomPainter`), High/Target/Low progress bars
3. Horizontal scroll stats row: Avg Glucose · Est. GMI · Variability
4. Dawn Phenomenon `GlassCard`
5. Quick actions 2-column grid:
   - **Log Bolus** → `LogBolusScreen`
   - **Log Hypo** → `HypoTrackerScreen` (list view — lets user see history then tap FAB to log)

### 5.4 StatsScreen (`lib/screens/statistics_screen.dart`) — REBUILT
- Day selector tabs: 7 / 14 / 30
- `GET /api/v1/glucose/report?days=N` feeds all sections
- Sections: Time In Range, Variability (CV, SD), Patterns, AGP summary, Dawn Phenomenon detail

### 5.5 InsightsScreen (`lib/screens/ai_insights_screen.dart`) — REBUILT
Merges old `AiInsightsScreen` + `MonthlyReportScreen`. Three independently-loaded sections each with their own `_loading` / `_error` state pair:

1. **Weekly AI Insight** — `POST /api/v1/insights/analyse` (cached daily). States: `_insightLoading`, `_insightError`, `_insight`. Refresh button re-calls the endpoint.
2. **Monthly Report** — `POST /api/v1/reports/monthly?days=30`. States: `_reportLoading`, `_reportError`. On success opens PDF URL via `url_launcher`.
3. **Meal Correlation** — `MealService.getCorrelation()` called in `initState()`. States: `_correlationLoading`, `_correlationError`, `_correlations`. Each `MealCorrelation` item is color-coded: `avg_spike > 60` → danger red; `30–60` → warning amber; `< 30` → success green.

If one section errors, the other two render normally. Section errors show an inline "Retry" button scoped to that section only.

### 5.6 HypoTrackerScreen (`lib/screens/hypo_tracker_screen.dart`) — NEW
- Sticky header: "Hypo Tracker" + "Review your low events" subtitle
- Summary `GlassCard` (Last 7 Days): total events, avg lowest (mg/dL), avg duration, day/night split — computed from `ApiService.getHypoHistory()`
- Chronological event list: each item shows lowest value in red circle, timestamp, duration, treatment
- Red FAB (bottom-right) → `LogHypoFormScreen`

### 5.7 LogHypoFormScreen (`lib/screens/log_hypo_screen.dart`) — RESTYLED
- Dark glass form, same fields as current
- On submit: `POST /api/v1/hypo` (via existing `OfflineCacheService` path)
- On success: `Navigator.pop()` back to caller + SnackBar "Hypo logged"

### 5.8 LogBolusScreen (`lib/screens/log_bolus_screen.dart`) — RESTYLED
- Dark glass form, same fields
- Today's log panel: fetches from `ApiService.getBolusHistory()` filtered to today; falls back to `OfflineCacheService` local cache if offline
- Timing advisor banner: `GET /api/v1/bolus/timing`

### 5.9 LogBasalScreen (`lib/screens/log_basal_screen.dart`) — RESTYLED
- Dark glass form, same fields
- Today's log panel: fetches from `ApiService.getBasalHistory()` filtered to today; falls back to local cache if offline

### 5.10 LogMealScreen (`lib/screens/log_meal_screen.dart`) — NEW
- Meal type selector: 3 tappable `GlassCard` tiles (Low GI / Medium GI / High GI)
- Carbs input (g), Description text field, Glucose Before numeric input
- Submit → `MealService.logMeal()` → on success: `Navigator.pop()` + SnackBar "Meal logged"
- No today's log panel (meal is online-only; no local cache)

### 5.11 ProfileScreen (`lib/screens/profile_screen.dart`) — REBUILT
- Avatar: teal gradient circle with initials from local name
- Name (from `UserProfileService`) + email (from `AuthService.getMe()`)
- **App Preferences** `GlassCard`: glucose unit toggle → calls `AuthService.updateMe(glucoseUnit: ...)` and also updates `UserProfileService` local cache
- **Notifications** `GlassCard`: high alert toggle, low alert toggle (via `UserProfileService`); weekly insights toggle (local only)
- **CGM / Juggluco** `GlassCard`: Juggluco enabled toggle + URL field (kept from existing `ProfileScreen`)
- **Logout** button (danger border) → `AuthService.logout()` + `navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false)`

---

## 6. Removed Screens & Services
| Item | Reason |
|------|--------|
| `LogHubScreen` | Replaced by `LogBottomSheet` |
| `WellnessScreen` + `WellnessService` | Not in new design; vitamin/water reminders intentionally removed |
| `BolusAdvisorScreen` (`bolus_advisor_screen.dart`) | Timing advisor integrated as banner inside `LogBolusScreen` |
| `AlertThresholdsScreen` | Collapsed into `ProfileScreen` Notifications card |
| `TargetRangeScreen` | Collapsed into `ProfileScreen` |
| `JugglucoUrlScreen` | Collapsed into `ProfileScreen` CGM card |
| `EditProfileScreen` | Replaced by `RegisterScreen` (onboarding) + `ProfileScreen` (editing) |
| `MonthlyReportScreen` | Merged into `InsightsScreen` |

---

## 7. Error Handling & Data Flow

- **401 anywhere** → `AuthService.logout()` + `navigatorKey` reset to `/login` (including during `OfflineCacheService.syncPending()`)
- **Loading states** → each screen/section has its own `_loading` bool; shows centered `CircularProgressIndicator` (teal)
- **InsightsScreen** → three independent `_loading`/`_error` pairs (see Section 5.5)
- **API errors** → `SnackBar` with server error message
- **No connectivity** → inline error card with "Retry" button (`connectivity_plus`)
- **Offline queue** — `OfflineCacheService` used for bolus/basal; meal logging online-only

---

## 8. Files Changed Summary

| Action | Files |
|--------|-------|
| **New** | `auth_service.dart`, `meal_service.dart`, `login_screen.dart`, `register_screen.dart`, `hypo_tracker_screen.dart`, `log_meal_screen.dart`, `widgets/glass_card.dart`, `widgets/floating_nav_bar.dart`, `widgets/glass_text_field.dart` |
| **Rebuilt** | `colors.dart`, `theme.dart`, `main.dart`, `main_screen.dart`, `home_screen.dart`, `statistics_screen.dart`, `ai_insights_screen.dart`, `log_hypo_screen.dart` (→ `LogHypoFormScreen`), `profile_screen.dart`, `api_service.dart`, `primary_button.dart` |
| **Restyled** | `log_bolus_screen.dart`, `log_basal_screen.dart` |
| **Removed** | `log_hub_screen.dart`, `wellness_screen.dart`, `bolus_advisor_screen.dart`, `alert_thresholds_screen.dart`, `target_range_screen.dart`, `juggluco_url_screen.dart`, `edit_profile_screen.dart`, `monthly_report_screen.dart`, `wellness_service.dart` |
| **Unchanged** | `juggluco_service.dart`, `alert_service.dart`, `offline_cache_service.dart`, `notification_plugin.dart`, `user_profile_service.dart`, `models/`, `badge_chip.dart`, `glucose_card.dart`, `metric_card.dart` |
