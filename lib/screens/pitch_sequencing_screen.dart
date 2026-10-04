import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_session.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/stat_vbox.dart';
import '../widgets/year_filter_dropdown.dart';
import 'plus_lock_card.dart';

class PitchSequencingScreen extends StatefulWidget {
  const PitchSequencingScreen({super.key});

  @override
  State<PitchSequencingScreen> createState() => _PitchSequencingScreenState();
}

class _PitchSequencingScreenState extends State<PitchSequencingScreen> {
  String _team = 'All';
  String _gameNum = 'All';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    if (!session.isPlus) {
      return const PlusLockCard(feature: 'Pitch Sequencing');
    }
    var data = session.filteredPitches;
    if (_team != 'All') data = data.where((p) => p.game == _team).toList();
    if (_gameNum != 'All') {
      final gn = int.tryParse(_gameNum);
      data = data.where((p) => p.gameNumber == gn).toList();
    }
    final seqs = StatsService.pitchSequencing(data);
    final putAway = StatsService.putAwayPitch(data);
    final firstPitchStrike = StatsService.firstPitchStrikeByType(data);
    final teams = ['All', ...session.knownTeams];
    final gameNums = [
      'All',
      ...session.filteredPitches
          .where((p) => _team == 'All' || p.game == _team)
          .map((p) => p.gameNumber.toString())
          .toSet()
    ];
    final pitchTypesUsed = {
      for (final p in data) if (p.pitchType != null) p.pitchType!
    }.toList()
      ..sort();

    final filterRow = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _team,
                    decoration: const InputDecoration(labelText: 'Team'),
                    items: teams.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() {
                      _team = v!;
                      _gameNum = 'All';
                    }),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _gameNum,
                    decoration: const InputDecoration(labelText: 'Game #'),
                    items: gameNums.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _gameNum = v!),
                  ),
                ),
                const YearFilterDropdown(),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 6, children: [
              const LegendChip(label: 'Favorable sequence (higher Out%/K%)', color: AppColors.colSuccess),
              const LegendChip(label: 'Sequence to avoid', color: AppColors.colError),
              if (pitchTypesUsed.isNotEmpty) ...[
                const SizedBox(width: 4),
                const Text('Pitch colors:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                for (final pt in pitchTypesUsed)
                  LegendChip(label: pt.toUpperCase(), color: AppColors.pitchColor(pt)),
              ],
            ]),
          ],
        ),
      ),
    );

    if (seqs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          filterRow,
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Not enough data yet (need 3-pitch sequences).',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      );
    }

    final best = List<Map<String, dynamic>>.from(seqs)
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final worst = seqs.where((s) => (s['count'] as int) >= 3).toList()
      ..sort((a, b) => (a['score'] as double).compareTo(b['score'] as double));
    final heatmap = StatsService.countHeatmap(data);

    Widget seqCard(Map<String, dynamic> s, bool good) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: good ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
            border: Border.all(color: good ? AppColors.colSuccess : AppColors.colError, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(s['seq'] as String,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: good ? AppColors.perfExcellent : AppColors.colError)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: perfHex('seq_score', s['score'] as double?),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Score ${s['score']}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 2),
              Text('Out%: ${s['outPct']}%  |  K%: ${s['kPct']}%  |  n=${s['count']} PA'
                  '${s['weakContactPct'] != null ? '  |  Weak contact: ${s['weakContactPct']}%' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 3),
              Wrap(spacing: 4, runSpacing: 4, children: [
                if (s['repeatAll3'] == true)
                  const _MiniTag(text: 'Same pitch 3x', color: AppColors.perfPoor)
                else if ((s['uniqueTypes'] as int) >= 3)
                  const _MiniTag(text: 'Full variety', color: AppColors.perfExcellent)
                else if ((s['speedChanges'] as int) >= 1)
                  const _MiniTag(text: 'Speed change', color: AppColors.perfGood),
              ]),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filterRow,
        const SizedBox(height: 8),
        ResponsiveRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Best Sequences (Top 5)', style: TextStyle(fontWeight: FontWeight.w800)),
                      const Text('Ranked by Sequence Score — results, weak contact, and speed/shape variety, not just raw count.',
                          style: TextStyle(fontSize: 10.5, color: AppColors.colMuted)),
                      const SizedBox(height: 8),
                      for (final s in best.take(5)) seqCard(s, true),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sequences to Avoid', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (worst.isEmpty)
                        const Text('Need more data.', style: TextStyle(color: Colors.grey))
                      else
                        for (final s in worst.take(4)) seqCard(s, false),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Put-Away Pitch (Final Pitch of K)', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (putAway.isEmpty)
                  const Text('No strikeouts logged yet.', style: TextStyle(color: Colors.grey))
                else
                  for (final p in putAway)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: _PitchBarRow(
                        pitchType: p['pitchType'] as String,
                        pct: p['pct'] as double,
                        detail: '${p['pct']}% (${p['count']}/${p['ofTotal']} K)',
                      ),
                    ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('First-Pitch Strike% by Pitch Type', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (firstPitchStrike.isEmpty)
                  const Text('No first pitches logged yet.', style: TextStyle(color: Colors.grey))
                else
                  for (final p in firstPitchStrike)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: _PitchBarRow(
                        pitchType: p['pitchType'] as String,
                        pct: p['pct'] as double,
                        detail: '${p['pct']}% (${p['count']}/${p['ofTotal']} 1st pitches)',
                      ),
                    ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pitch Usage Heat Map by Count', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const Text(
                  'Each cell: Strike% (left) · Usage% (center) · BAA (right). Colors are scored independently on a 5-tier scale.',
                  style: TextStyle(fontSize: 11, color: AppColors.colMuted),
                ),
                const SizedBox(height: 10),
                _PitchUsageHeatmap(heatmap: heatmap),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Formats a batting-average-style value the traditional way (".287"
/// rather than "0.287"), without breaking for the rare 1.000 case.
String _fmtAvg(double v) {
  final s = v.toStringAsFixed(3);
  return s.startsWith('0.') ? s.substring(1) : s;
}

/// One "pitch tag + progress bar + detail" row. The tag is width-bounded (so
/// long custom pitch names ellipsize instead of overflowing) and the detail
/// text sits under the bar so it can wrap instead of squeezing the bar.
class _PitchBarRow extends StatelessWidget {
  final String pitchType;
  final double pct;
  final String detail;
  const _PitchBarRow({required this.pitchType, required this.pct, required this.detail});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.pitchColor(pitchType);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56, maxWidth: 104),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: Text(
              pitchType.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 14,
                backgroundColor: AppColors.colBorder,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.colText)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniTag({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

/// Larger, three-part-per-cell heat map: Strike% / Usage% / BAA, each
/// colored independently on the shared 5-tier perf scale (item 11).
class _PitchUsageHeatmap extends StatelessWidget {
  final Map<String, dynamic> heatmap;
  const _PitchUsageHeatmap({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final counts = heatmap['counts'] as List<String>;
    final pitchTypes = heatmap['pitchTypes'] as List<String>;
    final cells = heatmap['cells'] as Map<String, Map<String, dynamic>>;
    final countTotals = heatmap['countTotals'] as Map<String, int>;

    if (pitchTypes.isEmpty) {
      return const Text('No pitch data yet.', style: TextStyle(color: Colors.grey));
    }

    Widget cellWidget(String count, String pt) {
      final key = '$count|$pt';
      final c = cells[key];
      if (c == null) {
        return Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surfaceAlt, border: Border.all(color: AppColors.colBorder, width: 2)),
          child: const Text('—', style: TextStyle(color: Colors.grey, fontSize: 11)),
        );
      }
      final strikePct = c['strikePct'] as double?;
      final usagePct = c['usagePct'] as double?;
      final baa = c['baa'] as double?;
      final strikeBg = perfHex('f_strike', strikePct);
      final usageBg = perfHex('usage_predictability', usagePct);
      final baaBg = perfHex('AVG', baa);
      Color tc(Color bg) => (bg == AppColors.perfExcellent || bg == AppColors.perfPoor || bg == AppColors.perfBelowAvg)
          ? Colors.white
          : AppColors.colText;
      Widget third(Color bg, String label, String value) => Container(
            width: double.infinity,
            color: bg,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: tc(bg).withOpacity(0.75))),
              Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tc(bg))),
            ]),
          );
      return Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.colBorder, width: 2)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          third(strikeBg, 'STR%', strikePct != null ? '${strikePct.toStringAsFixed(0)}' : '—'),
          third(usageBg, 'USE%', usagePct != null ? '${usagePct.toStringAsFixed(0)}' : '—'),
          third(baaBg, 'BAA', baa != null ? _fmtAvg(baa) : '—'),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Size every column to fit the available card width exactly (instead
      // of fixed pixel widths inside a horizontally-scrolling container) so
      // the whole heat map is visible without scrolling right.
      // Label column grows with the longest (custom) pitch name, within bounds.
      final longestPitch = pitchTypes.fold<int>(0, (a, p) => p.length > a ? p.length : a);
      final labelColWidth = (longestPitch * 6.5 + 12).clamp(46.0, 88.0).toDouble();
      // Each cell holds three stacked values (".287", "STR%", ...), so a column
      // needs a minimum width to stay legible. On narrow screens the table keeps
      // that width and scrolls sideways instead of crushing 12 columns to ~20px.
      const minColWidth = 54.0;
      final neededWidth = labelColWidth + counts.length * minColWidth;
      final tableWidth = constraints.maxWidth >= neededWidth ? constraints.maxWidth : neededWidth;
      final available = (tableWidth - labelColWidth).clamp(0.0, double.infinity);
      final colWidth = counts.isEmpty ? available : available / counts.length;

      final table = Table(
        defaultColumnWidth: FixedColumnWidth(colWidth),
        columnWidths: {0: FixedColumnWidth(labelColWidth)},
        border: TableBorder.all(color: AppColors.colBorder, width: 2),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.ink),
            children: [
              const Padding(
                padding: EdgeInsets.all(4),
                child: Text('Pitch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9)),
              ),
              for (final count in counts)
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                    Text('n=${countTotals[count] ?? 0}',
                        style: const TextStyle(fontSize: 7.5, color: Colors.white70)),
                  ]),
                ),
            ],
          ),
          for (final pt in pitchTypes)
            TableRow(children: [
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                color: AppColors.surfaceAlt,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.pitchColor(pt), shape: BoxShape.circle)),
                  const SizedBox(height: 2),
                  Text(pt.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9),
                      textAlign: TextAlign.center),
                ]),
              ),
              for (final count in counts) cellWidget(count, pt),
            ]),
        ],
      );
      if (constraints.maxWidth >= neededWidth) return table;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: tableWidth, child: table),
      );
    });
  }
}
