# Pitching Analytics — Flutter Port

A Flutter/Dart recreation of the original R Shiny "Pitching Analytics" app —
same feature set, same navigation, same color system and statistical
formulas, rebuilt as a cross-platform app for **Windows, iOS, Android, and
Web**.

---

## 1. What's in this project

```
lib/
  main.dart                     Entry point — wires services, shows Login or Home
  theme/
    app_theme.dart              Exact color ports of the R app's CSS variables
  models/
    user.dart                   Account model (tier/status enums)
    pitch_event.dart            One logged pitch/pickoff row (mirrors the R CSV schema)
  services/
    storage_service.dart        Local JSON persistence (shared_preferences)
    auth_service.dart           Login/signup/admin user CRUD, salted SHA-256 hashing
    app_session.dart            App-wide state + live game-input state machine
    stats_service.dart          *All* statistical formulas, ported from the R app
  widgets/
    baseball_field_painter.dart CustomPainter recreation of draw_field()
    sidebar_nav.dart            Collapsible sidebar navigation
    stat_vbox.dart               Colored stat box / legend chip widgets
  screens/
    login_screen.dart / signup_screen.dart
    home_shell.dart             Sidebar + content-switching shell
    game_input_screen.dart      Live pitch logging (counts, outs, pitch tree, spray tap)
    overview_screen.dart        Season/game stat boxes (ERA, WHIP, AVG, K%, etc.)
    pitch_breakdown_screen.dart Usage% chart + pitch arsenal table
    count_approach_screen.dart  Ahead/Behind/Even OBP buckets (Plus)
    spray_chart_screen.dart     Filterable spray chart
    game_logs_screen.dart       Per-game log table + ERA/WHIP/K% trend lines
    pitch_sequencing_screen.dart 3-pitch sequence analysis + put-away pitch (Plus)
    scouting_report_screen.dart Opponent-specific report + key hitters (Plus)
    edit_raw_data_screen.dart   Editable/deletable table of every logged pitch
    edit_at_bats_screen.dart    Pick a ball-in-play row, tap the field to (re)plot it
    admin_panel_screen.dart     Full user CRUD: create, delete, reset password, change tier/status
```

## 2. Formulas preserved exactly

Per the project brief, `lib/services/stats_service.dart` is a deliberate,
close port of the R app's calculation logic — **not** a rewrite:

- `perfHex()` reproduces `perf_hex()`'s exact piecewise thresholds for ERA,
  WHIP, K%, BB%, Whiff%, F-Strike%, K-BB%, AVG, and OBP-allowed color tiers.
- `overview()` reproduces `ov_stats`: IP from out-counting (including
  pickoffs/throwouts as outs), ERA = runs×9/IP, WHIP = (BB+H)/IP,
  AVG = H/AB, SLG = TB/AB, K% / BB% / K-BB% off plate appearances,
  Whiff% = whiffs/swings.
- `gameLog()`, `pitchBreakdown()`, `pitchSequencing()`, `putAwayPitch()`,
  and `countApproach()` are direct ports of the corresponding R reactives
  (`game_log_data`, `pitch_sum`, `seq_data`, and `cnt_data`).

**One structural simplification, called out honestly:** the R app
reconstructs plate-appearance boundaries *after the fact* from a flat
pitch-by-pitch CSV (see `process_data()`'s `pa_start`/`pa_id` logic). This
Flutter port instead assigns a plate-appearance id **at write time**, from
the live game-state machine in `AppSession.addPitch()` — since the app
itself controls pitch entry in real time, this is simpler and numerically
equivalent, but it means imported/bulk CSV data would need a small importer
to backfill `paId` correctly (not included here).

## 3. What's simplified vs. the R app (read this before assuming 100% parity)

This is an honest list — the original R app is a very large, mature
Shiny application (2,600+ lines of server logic alone). A faithful,
production-grade Flutter port of *everything* — the CSV import/export
workflows, PDF report generation, lineup-cycling edge cases, the
canvas-based spray modal, lock/unlock animations, lineup persistence
across app restarts beyond the current session, lineup-of-9 wraparound
prompts, lineup restore from history — is a multi-week engineering
project, not a single pass. What you have here is a **complete,
compilable architecture** with:

- ✅ Full auth (login/signup/admin CRUD) and tiered access (Basic/Plus/Admin)
- ✅ All statistical formulas ported faithfully (see above)
- ✅ All 11 feature screens present and functional, wired to real data
- ✅ Cross-platform persistence (no native DB plugin required)
- ✅ The spray-chart field rendered via a custom Canvas painter, matching
  the R `draw_field()` geometry
- 🟡 Simplified: PDF export (not included — see §5), CSV import/export
  (not included), lineup auto-restore across sessions, multi-game
  "predictability heatmap," and some visual polish (animations, mobile
  drawer transitions)
- 🟡 Simplified: charts use `fl_chart` rather than a pixel-identical
  ggplot recreation — data and axes are correct, styling is close but not
  identical

## 4. Setup

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install)
   (stable channel, 3.22+ recommended).
2. From the project root:
   ```bash
   flutter pub get
   ```
3. Run `flutter doctor` and resolve any platform-specific toolchain
   warnings (Xcode for iOS, Android Studio/SDK for Android, Visual Studio
   with "Desktop development with C++" for Windows).

## 5. Running

```bash
flutter run                 # picks a connected device/emulator
flutter run -d chrome        # Web
flutter run -d windows        # Windows desktop
```

**Creating your first admin account:** this app ships with *no* default
admin account and *no* hardcoded password — that's deliberate, so nobody
can log in as admin just by reading the source. To create your very
first admin, run the app once with your own credentials passed in:

```bash
flutter run --dart-define=SEED_ADMIN_USER=youradminname \
            --dart-define=SEED_ADMIN_PASS=SomeStrongPassword123
```

That creates the account in local storage on that run only. For every
run/build after that, drop those two flags — and never ship a release
build with them set, since that would bake the password into the
compiled app. Once you're logged in as that admin, use the in-app Admin
Panel to create any further admin/basic/plus accounts normally; you
won't need the bootstrap flags again.

## 6. Building release binaries

```bash
flutter build apk --release          # Android
flutter build ios --release          # iOS (requires macOS + Xcode, then archive in Xcode)
flutter build windows --release      # Windows
flutter build web --release          # Web (output in build/web)
```

## 7. Billing / getting paid (read this before launching)

**This app cannot charge real money as-is** — and that's intentional, not
a bug. Charging money requires a backend you control (to verify payments
via webhooks) plus a Stripe and/or Apple/Google developer account; none
of that can live safely inside a client app, and a client can never be
trusted to self-report "I paid."

Pricing is centralized in `lib/services/billing_service.dart`:
```dart
PricingConfig.basicMonthlyPriceUsd  // 4.99
PricingConfig.plusMonthlyPriceUsd   // 9.99
```
Change the two numbers there and every screen that shows a price
(currently: the signup plan cards) updates automatically.

`billing_service.dart` also has a `BillingService` stub with the two
methods you'll need (`startCheckout`, `restorePurchases`) and detailed
TODO comments on what real implementation goes where:

- **Web / Windows** → Stripe Checkout. Your backend creates a Checkout
  Session (Stripe secret key lives server-side only) and the app opens
  the returned URL.
- **iOS / Android** → Apple/Google require using their In-App Purchase
  system for subscriptions bought inside a native app. The practical way
  to do this without hand-rolling receipt validation is
  [RevenueCat](https://www.revenuecat.com/), which wraps both platforms'
  IAP behind one API and can also forward Stripe web purchases into the
  same entitlement system.
- **Either way**, the payment provider notifies **your backend** via
  webhook when a payment succeeds/renews/cancels, and your backend is
  what flips a user's `tier`/`status` — the same fields
  `AdminPanelScreen` already lets you edit by hand. Once you have that
  backend, swap `StorageService`'s user storage for calls to it (see
  §8), and have it push status changes down to the app.

Until real billing is wired up, `AuthService.signUp()` marks new
accounts `active` immediately (see the comment right above that line)
so the app remains fully testable end-to-end. Flip that one line to
`pendingPayment` once your webhook handler exists.

## 8. Extending this further

- **Swap storage**: everything talks to `StorageService`. Replace its
  body with `sqflite`/`drift` (mobile/desktop) or a REST/Firebase backend
  without touching any screen code.
- **PDF export**: add the `pdf` and `printing` packages and build report
  widgets analogous to the R app's `make_gamelog_pdf`/`make_spray_pdf`.
- **CSV import/export**: add `csv` + `file_picker` (mobile/desktop) or
  `file_selector` (web) and map rows to/from `PitchEvent.toJson()`.
- **Bulk-import plate-appearance reconstruction**: if you add CSV import,
  port the R `process_data()` PA-boundary logic (pitch_num==1 OR previous
  outcome ends a PA) to backfill `paId` for imported rows.

## 9. Known dependencies

See `pubspec.yaml`. Kept intentionally minimal (no native SQL plugin, no
platform channels) so that `flutter pub get` + `flutter run` should work
out of the box on every target platform without extra native setup.
