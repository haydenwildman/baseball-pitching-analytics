import '../models/pitch_event.dart';

/// One completed (or in-progress) plate appearance's full pitch sequence,
/// against a specific Team + Jersey #. Built by [BatterHistoryService] —
/// never constructed by hand.
class AtBatSequence {
  final String opponent;
  final int gameNumber;
  final int season;
  final DateTime date; // timestamp of the last pitch in this at-bat
  final List<PitchEvent> pitches; // chronological, one per pitch thrown
  final List<(String, String)> counts; // (before, after) per pitch, aligned to `pitches`
  final String? finalOutcome; // e.g. 'k', 'bb', 'go' — null if still in progress
  final bool ballInPlay;

  const AtBatSequence({
    required this.opponent,
    required this.gameNumber,
    required this.season,
    required this.date,
    required this.pitches,
    required this.counts,
    required this.finalOutcome,
    required this.ballInPlay,
  });

  /// The single pitch that was put in play, if any — used to render this
  /// at-bat's spray-chart location.
  PitchEvent? get ballInPlayPitch {
    for (final p in pitches) {
      if (p.call == 'ip' && p.xCoord != null && p.yCoord != null) return p;
    }
    return null;
  }
}

/// Aggregate tendencies against this specific Team + Jersey #, computed
/// only from previous at-bats against them — never used to suggest what to
/// throw, purely informational (per the redesign spec).
class BatterTendencies {
  final int totalAtBats;
  final int totalPitches;
  final Map<String, int> pitchUsageCounts; // pitchType key -> count
  final String? mostFrequentPitch;
  final Map<String, int> twoStrikePitchCounts; // pitchType key -> count
  final String? mostCommonTwoStrikePitch;
  final int strikeouts;
  final int walks;
  final int foulBalls;
  final int ballsInPlay;
  final String? lastPitchThrown;
  final String? lastOutcome;

  const BatterTendencies({
    required this.totalAtBats,
    required this.totalPitches,
    required this.pitchUsageCounts,
    required this.mostFrequentPitch,
    required this.twoStrikePitchCounts,
    required this.mostCommonTwoStrikePitch,
    required this.strikeouts,
    required this.walks,
    required this.foulBalls,
    required this.ballsInPlay,
    required this.lastPitchThrown,
    required this.lastOutcome,
  });

  bool get hasData => totalAtBats > 0;

  /// Usage % for a given pitch type key, or null if there's no data for it.
  double? usagePct(String key) {
    if (totalPitches == 0) return null;
    final n = pitchUsageCounts[key];
    if (n == null || n == 0) return null;
    return n / totalPitches * 100;
  }
}

/// The batter's own recorded offensive line against this pitcher, built
/// only from the same completed plate appearances already grouped in
/// [BatterHistory.atBats] — the exact same at-bat-ending outcomes the rest
/// of the app already uses (see [PAResult] in stats_service.dart), just
/// totaled for one batter instead of every batter faced. Any rate with an
/// empty denominator is left null so the UI can show "N/A" instead of a
/// misleading 0%.
class BatterOffenseStats {
  final int pa;
  final int ab;
  final int hits;
  final int walks;
  final int hitByPitch;
  final int strikeouts;
  final int homeRuns;
  final int totalBases;
  final int ballsInPlay;

  const BatterOffenseStats({
    required this.pa,
    required this.ab,
    required this.hits,
    required this.walks,
    required this.hitByPitch,
    required this.strikeouts,
    required this.homeRuns,
    required this.totalBases,
    required this.ballsInPlay,
  });

  double? get avg => ab > 0 ? hits / ab : null;
  double? get obp {
    final denom = ab + walks + hitByPitch;
    return denom > 0 ? (hits + walks + hitByPitch) / denom : null;
  }

  double? get slg => ab > 0 ? totalBases / ab : null;
  double? get ops {
    final o = obp, s = slg;
    return (o != null && s != null) ? o + s : null;
  }

  double? get bbPct => pa > 0 ? walks / pa * 100 : null;
  double? get kPct => pa > 0 ? strikeouts / pa * 100 : null;
  double? get babip {
    final denom = ab - strikeouts - homeRuns;
    return denom > 0 ? (hits - homeRuns) / denom : null;
  }
}

/// Everything known about previous encounters with one specific
/// Team + Jersey # (never jersey # alone — see [BatterHistoryService.build]),
/// across every game ever logged, oldest games included.
class BatterHistory {
  final String opponent;
  final int jersey;
  final List<AtBatSequence> atBats; // newest first
  final List<PitchEvent> sprayPoints; // every ball in play, across all at-bats
  final BatterTendencies tendencies;
  final BatterOffenseStats offense;

  const BatterHistory({
    required this.opponent,
    required this.jersey,
    required this.atBats,
    required this.sprayPoints,
    required this.tendencies,
    required this.offense,
  });

  bool get hasData => atBats.isNotEmpty;
  AtBatSequence? get lastAtBat => atBats.isEmpty ? null : atBats.first;
}

class BatterHistoryService {
  /// Builds the full cross-game history for [team] + [jersey]. Both must
  /// match — this is never looked up by jersey # alone, so the same # on a
  /// different team is correctly treated as a different batter.
  static BatterHistory build({
    required List<PitchEvent> allPitches,
    required String team,
    required int jersey,
  }) {
    // Only real pitches (not pickoffs/balks/etc.) count toward an at-bat
    // sequence. `allPitches` is already in chronological (append) order.
    final relevant = allPitches
        .where((p) =>
            p.eventType == 'pitch' && p.game == team && p.batterNumber == jersey)
        .toList();

    // Group into plate appearances. The same key used elsewhere in the app
    // to identify a unique PA (game + game# + season + batter seq + paId)
    // — including season/gameNumber here is what keeps two different games
    // against the same team from ever bleeding into each other.
    final order = <String>[];
    final groups = <String, List<PitchEvent>>{};
    for (final p in relevant) {
      final key = '${p.game}|${p.gameNumber}|${p.season}|${p.batter}|${p.paId}';
      if (!groups.containsKey(key)) order.add(key);
      groups.putIfAbsent(key, () => []).add(p);
    }

    final atBats = <AtBatSequence>[];
    for (final key in order) {
      final pitchesInPA = groups[key]!;
      final counts = <(String, String)>[];
      int b = 0, s = 0;
      for (final p in pitchesInPA) {
        final before = '$b-$s';
        switch (p.call) {
          case 'b':
            b++;
            break;
          case 'ss':
          case 'sl':
            s++;
            break;
          case 'f':
            if (s < 2) s++;
            break;
        }
        counts.add((before, '$b-$s'));
      }
      final last = pitchesInPA.last;
      atBats.add(AtBatSequence(
        opponent: last.game,
        gameNumber: last.gameNumber,
        season: last.season,
        date: last.timestamp,
        pitches: pitchesInPA,
        counts: counts,
        finalOutcome: last.isFinalPitchOfPA ? last.outcome : null,
        ballInPlay: pitchesInPA.any((p) => p.call == 'ip'),
      ));
    }

    // Newest first.
    atBats.sort((a, b) => b.date.compareTo(a.date));

    final sprayPoints = <PitchEvent>[
      for (final ab in atBats)
        if (ab.ballInPlayPitch != null) ab.ballInPlayPitch!,
    ];

    final tendencies = _computeTendencies(atBats, relevant);
    final offense = _computeOffense(atBats);

    return BatterHistory(
      opponent: team,
      jersey: jersey,
      atBats: atBats,
      sprayPoints: sprayPoints,
      tendencies: tendencies,
      offense: offense,
    );
  }

  /// Totals the batter's own offensive line from the same completed
  /// at-bats (`finalOutcome != null`) already grouped by [build] — same
  /// outcome-to-stat mapping the rest of the app uses (bb/hbp don't count
  /// as an AB; 1b/2b/3b/hr count as hits; k/kl count as a strikeout).
  static BatterOffenseStats _computeOffense(List<AtBatSequence> atBats) {
    int pa = 0, ab = 0, hits = 0, walks = 0, hbp = 0, k = 0, hr = 0, tb = 0, bip = 0;
    for (final at in atBats) {
      final outcome = at.finalOutcome;
      if (outcome == null) continue; // still in progress — not a final PA yet
      pa++;
      if (outcome == 'bb') {
        walks++;
      } else if (outcome == 'hbp') {
        hbp++;
      } else {
        ab++;
        if (PitchEvent.hitOutcomes.contains(outcome)) hits++;
        if (outcome == 'hr') hr++;
        if (PitchEvent.kOutcomes.contains(outcome)) k++;
      }
      if (at.ballInPlay) bip++;
      final finalPitch = at.pitches.isNotEmpty ? at.pitches.last : null;
      if (finalPitch != null) tb += finalPitch.totalBases;
    }
    return BatterOffenseStats(
      pa: pa,
      ab: ab,
      hits: hits,
      walks: walks,
      hitByPitch: hbp,
      strikeouts: k,
      homeRuns: hr,
      totalBases: tb,
      ballsInPlay: bip,
    );
  }

  static BatterTendencies _computeTendencies(
      List<AtBatSequence> atBats, List<PitchEvent> relevant) {
    final usage = <String, int>{};
    final twoStrike = <String, int>{};
    int strikeouts = 0, walks = 0, fouls = 0, bip = 0;

    for (final p in relevant) {
      final pt = p.pitchType;
      if (pt != null) usage[pt] = (usage[pt] ?? 0) + 1;
      if (p.call == 'f') fouls++;
      if (p.call == 'ip') bip++;
    }

    for (final ab in atBats) {
      if (ab.finalOutcome == 'k' || ab.finalOutcome == 'kl') strikeouts++;
      if (ab.finalOutcome == 'bb') walks++;
      for (var i = 0; i < ab.pitches.length; i++) {
        final before = ab.counts[i].$1; // "b-s"
        final strikesBefore = int.tryParse(before.split('-').last) ?? 0;
        if (strikesBefore >= 2) {
          final pt = ab.pitches[i].pitchType;
          if (pt != null) twoStrike[pt] = (twoStrike[pt] ?? 0) + 1;
        }
      }
    }

    String? mostFrequent(Map<String, int> m) {
      if (m.isEmpty) return null;
      var bestKey = m.keys.first;
      var bestVal = m[bestKey]!;
      for (final e in m.entries) {
        if (e.value > bestVal) {
          bestKey = e.key;
          bestVal = e.value;
        }
      }
      return bestKey;
    }

    final lastAb = atBats.isEmpty ? null : atBats.first;

    return BatterTendencies(
      totalAtBats: atBats.length,
      totalPitches: relevant.length,
      pitchUsageCounts: usage,
      mostFrequentPitch: mostFrequent(usage),
      twoStrikePitchCounts: twoStrike,
      mostCommonTwoStrikePitch: mostFrequent(twoStrike),
      strikeouts: strikeouts,
      walks: walks,
      foulBalls: fouls,
      ballsInPlay: bip,
      lastPitchThrown: lastAb?.pitches.last.pitchType,
      lastOutcome: lastAb?.finalOutcome,
    );
  }
}
