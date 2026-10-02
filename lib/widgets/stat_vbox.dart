import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/stats_service.dart' show statProgressFraction;
import 'stat_hold_info.dart';

/// Port of the R app's `.stat-vbox` / `mk_vb()` helper: a colored box
/// with a small uppercase label and a large bold value. If [description]
/// is provided, pressing and holding the box shows an explanation of what
/// the stat means (released = dismissed); see [StatHoldInfo].
class StatVBox extends StatelessWidget {
  final String label;
  final String value;
  final Color background;
  final Color textColor;
  final String? description;

  /// When true, renders with tighter padding and smaller type — used on
  /// screens like Pitch Breakdown where many boxes are shown at once and
  /// the default sizing leaves a lot of empty color around each value.
  final bool compact;

  const StatVBox({
    super.key,
    required this.label,
    required this.value,
    this.background = AppColors.blueLight,
    this.textColor = AppColors.colText,
    this.description,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final vPad = compact ? 5.0 : 8.0;
    final hPad = compact ? 5.0 : 6.0;
    final labelSize = compact ? 8.5 : 10.0;
    final valueSize = compact ? 14.0 : 18.0;
    final gap = compact ? 1.0 : 3.0;

    return StatHoldInfo(
      title: label,
      description: description,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(compact ? 7 : 10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: textColor.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: gap),
            Text(
              value,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal progress bar whose FILLED LENGTH is driven primarily by
/// which of the 5 perf-tier colors [color] is (Excellent/Good/Average/
/// BelowAvg/Poor), so every stat still visually communicates its quality
/// tier at a glance — but *within* that tier, the length also reflects
/// where the raw value actually falls, so two "Good" stats don't render
/// as identical bars when one is barely Good and the other is nearly
/// Excellent. Pass [rawValue] and [statKey] (the same key used for
/// [perfHex]) to get this graduated sizing; the five small dots under the
/// track mark where each next color tier begins. Without them, the bar
/// falls back to a flat, ungraded fill (used for plain counts like PA/IP).
/// The actual value is shown as text inside the filled portion of the bar.
class PerfStatBar extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? description;

  /// Raw numeric value behind [value] (e.g. 3.62 for an ERA shown as
  /// "3.62"), used together with [statKey] to place the bar continuously
  /// within its color tier instead of snapping to a fixed tier length.
  final double? rawValue;

  /// The [perfHex] stat key (e.g. 'ERA', 'K_pct') that [color] and
  /// [rawValue] were computed from. Leave null for plain counts that
  /// aren't performance-graded.
  final String? statKey;

  /// Short benchmark text (e.g. "Elite 30%+ · Poor ≤10%") shown under the
  /// bar so the value can be judged against a typical scale, not just
  /// read in isolation. Pass `StatsService.statScaleHint(statKey)`, or
  /// leave null for plain counts (PA, IP, etc.) that have no benchmark.
  final String? scaleHint;

  const PerfStatBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.description,
    this.rawValue,
    this.statKey,
    this.scaleHint,
  });

  /// Continuous 0..1 fill length: uses the value's actual position on the
  /// stat's scale when [statKey]/[rawValue] are given, otherwise falls
  /// back to a flat full bar (plain, non-tiered counts like PA/IP).
  double get _fraction => statProgressFraction(statKey, rawValue);

  /// Where each next perf tier begins along the track (tiers are always
  /// even fifths), and which color starts there — e.g. the dot at 20%
  /// marks "Below Avg starts here" in that tier's color.
  static const List<_TierTick> _tierKeyTicks = [
    _TierTick(0.2, AppColors.perfBelowAvg),
    _TierTick(0.4, AppColors.perfAverage),
    _TierTick(0.6, AppColors.perfGood),
    _TierTick(0.8, AppColors.perfExcellent),
  ];

  /// Text sitting on top of [bg] needs to be readable against it — white on
  /// the dark/saturated tier colors, dark text on the light ones.
  static Color _onBarTextColor(Color bg) {
    if (bg == AppColors.perfExcellent ||
        bg == AppColors.perfPoor ||
        bg == AppColors.perfBelowAvg ||
        bg == AppColors.blueMid) {
      return Colors.white;
    }
    return AppColors.colText;
  }

  @override
  Widget build(BuildContext context) {
    final frac = _fraction;
    // Plain/unrated counts (PA, IP, ...) use blueLight fill — render the
    // bar itself in the stronger blueMid so it's visible against the track.
    final barColor = color == AppColors.blueLight ? AppColors.blueMid : color;
    final onBarColor = _onBarTextColor(barColor);
    // Graded stats only: small dots marking where each next tier begins,
    // so the bar doubles as its own color key.
    final showKeyDots = statKey != null;

    return StatHoldInfo(
      title: label,
      description: description,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppColors.colMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Full-width track; the filled portion (length = value's position
          // within its perf tier) shows the stat's value inside it,
          // right-aligned within the fill. For graded stats, small dots
          // mark where each next color tier begins, doubling as a key.
          SizedBox(
            width: double.infinity,
            height: 26,
            child: LayoutBuilder(builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.colBorder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: frac,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: onBarColor,
                        ),
                      ),
                    ),
                  ),
                  if (showKeyDots)
                    for (final tick in _tierKeyTicks)
                      Positioned(
                        left: (trackWidth * tick.at) - 3.5,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tick.color,
                              border: Border.all(color: Colors.white, width: 1.25),
                            ),
                          ),
                        ),
                      ),
                ],
              );
            }),
          ),
          if (scaleHint != null) ...[
            const SizedBox(height: 3),
            Text(
              scaleHint!,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.colMuted,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// A single tier-boundary marker on a [PerfStatBar] track: [at] is the 0..1
/// position along the bar, [color] is the tier that begins there.
class _TierTick {
  final double at;
  final Color color;
  const _TierTick(this.at, this.color);
}

/// Reusable "what do the colors mean" key for any screen that uses the
/// 5-tier perf_hex color coding (green → yellow → orange → red).
/// Drop `const PerfTierLegend()` into a Filter card on any stats screen.
class PerfTierLegend extends StatelessWidget {
  const PerfTierLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: const [
      LegendChip(label: '5 – Excellent', color: AppColors.perfExcellent),
      LegendChip(label: '4 – Good', color: AppColors.perfGood),
      LegendChip(label: '3 – Avg', color: AppColors.perfAverage, textColor: AppColors.colText),
      LegendChip(label: '2 – Below', color: AppColors.perfBelowAvg),
      LegendChip(label: '1 – Poor', color: AppColors.perfPoor),
    ]);
  }
}

/// Small colored legend chip, e.g. "5 – Excellent" swatches.
class LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const LegendChip({
    super.key,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
