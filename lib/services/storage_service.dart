import '../models/pitch_event.dart';
import 'supabase_config.dart';

/// ══════════════════════════════════════════════════════════════
/// STORAGE SERVICE
///
/// Backed by Supabase Postgres now — `public.pitch_events` for every
/// logged pitch/event, and a `settings` jsonb column on
/// `public.profiles` for the small per-user config blobs (custom
/// pitch types, hidden built-ins, batter names, pitch type display
/// names/colors). Row Level Security (see supabase_schema.sql)
/// enforces that a user can only read/write their own rows; admins
/// can read everyone's (used nowhere in the UI yet, but available).
///
/// Public API intentionally unchanged from the old local-storage
/// version — AppSession and every screen that calls this class needed
/// no changes.
/// ══════════════════════════════════════════════════════════════
class StorageService {
  // ── PITCH DATA (per user) ───────────────────────────────
  Future<List<PitchEvent>> loadPitchesForUser(String userId) async {
    final rows = await sb.from('pitch_events').select().eq('user_id', userId).order('ts');
    return (rows as List).map((r) => _pitchFromRow(r as Map<String, dynamic>)).toList();
  }

  /// Syncs the full in-memory pitch list to Supabase: upserts every
  /// pitch (insert-or-update by id) and deletes any row that's no
  /// longer present locally (covers undo). Cheaper than a wipe-and-
  /// reinsert on every single pitch logged, and safe if a call fails
  /// partway (nothing already-saved gets lost).
  Future<void> savePitchesForUser(String userId, List<PitchEvent> pitches) async {
    if (pitches.isEmpty) {
      await sb.from('pitch_events').delete().eq('user_id', userId);
      return;
    }
    final existingIds = ((await sb.from('pitch_events').select('id').eq('user_id', userId)) as List)
        .map((r) => r['id'] as String)
        .toSet();
    final currentIds = pitches.map((p) => p.id).toSet();
    final toDelete = existingIds.difference(currentIds);
    if (toDelete.isNotEmpty) {
      await sb.from('pitch_events').delete().inFilter('id', toDelete.toList());
    }
    await sb.from('pitch_events').upsert(pitches.map((p) => _pitchToRow(p, userId)).toList());
  }

  Map<String, dynamic> _pitchToRow(PitchEvent p, String userId) => {
        'id': p.id,
        'user_id': userId,
        'game': p.game,
        'game_number': p.gameNumber,
        'batter': p.batter,
        'batter_number': p.batterNumber,
        'batting_order': p.battingOrder,
        'hand': p.hand,
        'event_type': p.eventType,
        'pitch_num': p.pitchNum,
        'pitch_type': p.pitchType,
        'call': p.call,
        'outcome': p.outcome,
        'ab': p.ab,
        'outs': p.outs,
        'er': p.er,
        'x_coord': p.xCoord,
        'y_coord': p.yCoord,
        'batted_type': p.battedType,
        'inning': p.inning,
        'pa_id': p.paId,
        'season': p.season,
        'ts': p.timestamp.toIso8601String(),
      };

  PitchEvent _pitchFromRow(Map<String, dynamic> r) => PitchEvent(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        game: r['game'] as String,
        gameNumber: r['game_number'] as int,
        batter: r['batter'] as int,
        batterNumber: r['batter_number'] as int?,
        battingOrder: r['batting_order'] as int? ?? 1,
        hand: r['hand'] as String? ?? 'R',
        eventType: r['event_type'] as String? ?? 'pitch',
        pitchNum: r['pitch_num'] as int?,
        pitchType: r['pitch_type'] as String?,
        call: r['call'] as String?,
        outcome: r['outcome'] as String?,
        ab: r['ab'] as int? ?? 0,
        outs: r['outs'] as int? ?? 0,
        er: (r['er'] as num?)?.toDouble() ?? 0,
        xCoord: (r['x_coord'] as num?)?.toDouble(),
        yCoord: (r['y_coord'] as num?)?.toDouble(),
        battedType: r['batted_type'] as String?,
        inning: r['inning'] as int?,
        paId: r['pa_id'] as int? ?? 0,
        season: r['season'] as int,
        timestamp: DateTime.tryParse(r['ts'] as String? ?? '') ?? DateTime.now(),
      );

  // ── PER-USER SETTINGS (custom pitch types, batter names, ...) ──
  // All five small blobs below share one jsonb column
  // (profiles.settings) to avoid a proliferation of tiny tables —
  // each read/write only touches its own key inside that object.
  Future<Map<String, dynamic>> _loadSettings(String userId) async {
    final row =
        await sb.from('profiles').select('settings').eq('id', userId).single();
    return (row['settings'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> _patchSettings(String userId, String key, dynamic value) async {
    final settings = await _loadSettings(userId);
    settings[key] = value;
    await sb.from('profiles').update({'settings': settings}).eq('id', userId);
  }

  Future<List<String>> loadCustomPitchTypes(String userId) async {
    final s = await _loadSettings(userId);
    return ((s['customPitchTypes'] as List?) ?? []).cast<String>();
  }

  Future<void> saveCustomPitchTypes(String userId, List<String> types) =>
      _patchSettings(userId, 'customPitchTypes', types);

  Future<List<String>> loadHiddenBuiltInPitchTypes(String userId) async {
    final s = await _loadSettings(userId);
    return ((s['hiddenBuiltInPitchTypes'] as List?) ?? []).cast<String>();
  }

  Future<void> saveHiddenBuiltInPitchTypes(String userId, List<String> types) =>
      _patchSettings(userId, 'hiddenBuiltInPitchTypes', types);

  /// Jersey # → player name. Stored with string keys (jsonb object keys
  /// are always strings) and converted back to int on read.
  Future<Map<int, String>> loadBatterNames(String userId) async {
    final s = await _loadSettings(userId);
    final map = (s['batterNames'] as Map<String, dynamic>?) ?? {};
    return map.map((k, v) => MapEntry(int.parse(k), v as String));
  }

  Future<void> saveBatterNames(String userId, Map<int, String> names) =>
      _patchSettings(userId, 'batterNames', names.map((k, v) => MapEntry(k.toString(), v)));

  Future<Map<String, String>> loadCustomPitchTypeNames(String userId) async {
    final s = await _loadSettings(userId);
    return ((s['customPitchTypeNames'] as Map<String, dynamic>?) ?? {}).cast<String, String>();
  }

  Future<void> saveCustomPitchTypeNames(String userId, Map<String, String> names) =>
      _patchSettings(userId, 'customPitchTypeNames', names);

  /// Pitch type key → color, as an 0xAARRGGBB int (jsonb-safe).
  Future<Map<String, int>> loadCustomPitchTypeColors(String userId) async {
    final s = await _loadSettings(userId);
    return ((s['customPitchTypeColors'] as Map<String, dynamic>?) ?? {})
        .map((k, v) => MapEntry(k, v as int));
  }

  Future<void> saveCustomPitchTypeColors(String userId, Map<String, int> colors) =>
      _patchSettings(userId, 'customPitchTypeColors', colors);
}
