import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/pitch_event.dart';

/// ══════════════════════════════════════════════════════════════
/// STORAGE SERVICE
///
/// The R app used SQLite (`users.db`) for accounts and per-user CSV/RDS
/// files for pitch data. To keep this Flutter app buildable on every
/// target platform (Windows, iOS, Android, Web) without native plugin
/// friction, persistence here uses `shared_preferences`, which is
/// backed by:
///   - NSUserDefaults on iOS/macOS
///   - SharedPreferences on Android
///   - a local file / registry on Windows/Linux
///   - localStorage on Web
///
/// Data is stored as JSON. This keeps the storage layer trivially
/// swappable for a real backend later (Firebase, Supabase, a REST API,
/// or sqflite/drift) — everything else in the app talks to this class,
/// never to shared_preferences directly.
///
/// If you outgrow this (e.g. very large pitch logs), swap the body of
/// this class for an sqflite/drift implementation; the public API
/// (loadUsers/saveUsers/loadPitchesForUser/...) should not need to change.
/// ══════════════════════════════════════════════════════════════
class StorageService {
  static const _usersKey = 'pa_users_v1';
  static const _pitchPrefix = 'pa_pitches_v1_'; // + userId
  static const _customPitchTypePrefix = 'pa_custom_pitch_types_v1_'; // + userId
  static const _hiddenBuiltInPitchTypePrefix =
      'pa_hidden_builtin_pitch_types_v1_'; // + userId
  static const _batterNamesPrefix = 'pa_batter_names_v1_'; // + userId
  static const _customPitchTypeNamesPrefix =
      'pa_custom_pitch_type_names_v1_'; // + userId
  static const _customPitchTypeColorsPrefix =
      'pa_custom_pitch_type_colors_v1_'; // + userId

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── USERS ────────────────────────────────────────────────
  Future<List<AppUser>> loadUsers() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveUsers(List<AppUser> users) async {
    final prefs = await _prefs;
    final raw = jsonEncode(users.map((u) => u.toJson()).toList());
    await prefs.setString(_usersKey, raw);
  }

  // ── PITCH DATA (per user) ───────────────────────────────
  Future<List<PitchEvent>> loadPitchesForUser(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_pitchPrefix$userId');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PitchEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePitchesForUser(
      String userId, List<PitchEvent> pitches) async {
    final prefs = await _prefs;
    final raw = jsonEncode(pitches.map((p) => p.toJson()).toList());
    await prefs.setString('$_pitchPrefix$userId', raw);
  }

  // ── CUSTOM PITCH TYPES (per user) ───────────────────────
  /// User-defined pitch type codes (initials typed in on Game Input),
  /// on top of the built-in FB/CV/CH/SL set.
  Future<List<String>> loadCustomPitchTypes(String userId) async {
    final prefs = await _prefs;
    return prefs.getStringList('$_customPitchTypePrefix$userId') ?? [];
  }

  Future<void> saveCustomPitchTypes(String userId, List<String> types) async {
    final prefs = await _prefs;
    await prefs.setStringList('$_customPitchTypePrefix$userId', types);
  }

  // ── HIDDEN BUILT-IN PITCH TYPES (per user) ──────────────
  /// Built-in pitch type codes (FB/CV/CH/SL) the user has removed from
  /// their Game Input pitch-type row.
  Future<List<String>> loadHiddenBuiltInPitchTypes(String userId) async {
    final prefs = await _prefs;
    return prefs.getStringList('$_hiddenBuiltInPitchTypePrefix$userId') ?? [];
  }

  Future<void> saveHiddenBuiltInPitchTypes(
      String userId, List<String> types) async {
    final prefs = await _prefs;
    await prefs.setStringList('$_hiddenBuiltInPitchTypePrefix$userId', types);
  }

  // ── BATTER NAMES (per user) ─────────────────────────────
  /// Jersey # → player name, stored as JSON since keys are ints.
  Future<Map<int, String>> loadBatterNames(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_batterNamesPrefix$userId');
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(int.parse(k), v as String));
  }

  Future<void> saveBatterNames(String userId, Map<int, String> names) async {
    final prefs = await _prefs;
    final raw = jsonEncode(names.map((k, v) => MapEntry(k.toString(), v)));
    await prefs.setString('$_batterNamesPrefix$userId', raw);
  }

  // ── CUSTOM PITCH TYPE DISPLAY NAMES (per user) ──────────
  /// Pitch type key (lowercase, e.g. "knuckleball") → the exact display
  /// name the user typed in (e.g. "Knuckleball"), so full pitch names can
  /// be shown everywhere instead of the short internal key.
  Future<Map<String, String>> loadCustomPitchTypeNames(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_customPitchTypeNamesPrefix$userId');
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveCustomPitchTypeNames(
      String userId, Map<String, String> names) async {
    final prefs = await _prefs;
    await prefs.setString(
        '$_customPitchTypeNamesPrefix$userId', jsonEncode(names));
  }

  // ── CUSTOM PITCH TYPE COLORS (per user) ─────────────────
  /// Pitch type key → color, stored as an 0xAARRGGBB hex string. This
  /// exact color is then used everywhere that pitch type appears (button,
  /// spray chart, pitch history, pitch breakdown, etc.) via
  /// [AppColors.setCustomPitchColors]/[AppColors.pitchColor].
  Future<Map<String, int>> loadCustomPitchTypeColors(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_customPitchTypeColorsPrefix$userId');
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as int));
  }

  Future<void> saveCustomPitchTypeColors(
      String userId, Map<String, int> colors) async {
    final prefs = await _prefs;
    await prefs.setString(
        '$_customPitchTypeColorsPrefix$userId', jsonEncode(colors));
  }

  /// Wipes everything — used only for testing / "reset app data".
  Future<void> wipeAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}
