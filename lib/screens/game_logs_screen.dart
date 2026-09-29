import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/app_session.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_vbox.dart';
import '../widgets/year_filter_dropdown.dart';

class GameLogsScreen extends StatefulWidget {
  const GameLogsScreen({super.key});

  @override
  State<GameLogsScreen> createState() => _GameLogsScreenState();
}

class _GameLogsScreenState extends State<GameLogsScreen> {
  String _team = 'All';
  String _gameNum = 'All';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    var data = session.filteredPitches;
    if (_team != 'All') data = data.where((p) => p.game == _team).toList();
    if (_gameNum != 'All') {
      final gn = int.tryParse(_gameNum);
      data = data.where((p) => p.gameNumber == gn).toList();
    }
    final log = StatsService.gameLog(data);
    final teams = ['All', ...session.knownTeams];
    final gameNums = [
      'All',
      ...session.filteredPitches
          .where((p) => _team == 'All' || p.game == _team)
          .map((p) => p.gameNumber.toString())
          .toSet()
    ];

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
                    value: _team,
                    decoration: const InputDecoration(labelText: 'Team'),
                    items: teams.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() {
                      _team = v!;
                      _gameNum = 'All';
                    }),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    value: _gameNum,
                    decoration: const InputDecoration(labelText: 'Game #'),
                    items: gameNums.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _gameNum = v!),
                  ),
                ),
                const YearFilterDropdown(),
              ],
            ),
            const SizedBox(height: 10),
            const PerfTierLegend(),
          ],
        ),
      ),
    );

    if (log.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          filterRow,
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No games logged yet.', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      );
    }

    List<FlSpot> spotsFor(String key) {
      final spots = <FlSpot>[];
      for (int i = 0; i < log.length; i++) {
        final v = log[i][key];
        if (v != null) spots.add(FlSpot(i.toDouble(), (v as num).toDouble()));
      }
      return spots;
    }

    Widget lineCard(String title, String key, Color lineColor, String perfStat) {
      final spots = spotsFor(key);
      // Fixed axis bounds so every tick maps to exactly one game index —
      // without this, fl_chart can pick a fractional label interval (e.g.
      // every 0.5 units) and the same opponent name gets drawn twice along
      // the line instead of once, right at its dot.
      final maxIndex = (log.length - 1).toDouble();
      // Pad the Y range so a dot sitting exactly at the data's min/max
      // isn't drawn right on the clip boundary (which was cutting the
      // circle markers in half at the top/bottom of the chart).
      double? minY, maxY;
      if (spots.isNotEmpty) {
        final ys = spots.map((s) => s.y).toList();
        final loY = ys.reduce((a, b) => a < b ? a : b);
        final hiY = ys.reduce((a, b) => a > b ? a : b);
        final range = hiY - loY;
        final pad = range > 0 ? range * 0.18 : (hiY == 0 ? 1.0 : hiY.abs() * 0.18);
        minY = loY - pad;
        maxY = hiY + pad;
        if (minY > 0 && loY >= 0 && minY < pad) minY = 0; // don't go negative for %/count stats needlessly
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 4),
              SizedBox(
                height: 240,
                child: spots.isEmpty
                    ? const Center(child: Text('—', style: TextStyle(color: Colors.grey)))
                    // Give every game its own fixed width (instead of squeezing
                    // all of them into whatever the card happens to be) so dots
                    // and opponent labels stay legible, and scroll horizontally
                    // for games that don't fit — never crop the graph.
                    : LayoutBuilder(builder: (context, constraints) {
                        const perPoint = 70.0;
                        final pointsWidth = log.length * perPoint;
                        final chartWidth =
                            pointsWidth > constraints.maxWidth ? pointsWidth : constraints.maxWidth;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            height: 240,
                            child: LineChart(
                              LineChartData(
                          minX: 0,
                          maxX: maxIndex < 0 ? 1 : maxIndex,
                          minY: minY,
                          maxY: maxY,
                          // Clip anything (dots, stroke, touch overlay) to the
                          // chart's own bounds so it can never bleed into the
                          // title above or the card below it.
                          clipData: const FlClipData.all(),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              color: lineColor,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  final color = perfHex(perfStat, spot.y);
                                  return FlDotCirclePainter(
                                    radius: 5,
                                    color: color,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => AppColors.blueDark,
                              tooltipRoundedRadius: 8,
                              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                                final i = s.x.toInt();
                                final label = (i >= 0 && i < log.length)
                                    ? '${log[i]['opponent']} #${log[i]['gameNumber']}\n'
                                    : '';
                                return LineTooltipItem(
                                  '$label${s.y.toStringAsFixed(2)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 34),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 54,
                                // Force exactly one tick per game index — the
                                // single fix that stops opponent labels from
                                // repeating along the connecting line.
                                interval: 1,
                                getTitlesWidget: (v, meta) {
                                  final i = v.round();
                                  // Only draw a label if v lands (near) exactly
                                  // on a real data-point index — this is what
                                  // keeps labels pinned to the dots only.
                                  if ((v - i).abs() > 0.01 || i < 0 || i >= log.length) {
                                    return const SizedBox();
                                  }
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Transform.rotate(
                                      angle: -0.5,
                                      child: SizedBox(
                                        width: 56,
                                        child: Text(
                                          '${log[i]['opponent']} #${log[i]['gameNumber']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: const FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                        ),
                              ),
                            ),
                          );
                        }),
              ),
            ],
          ),
        ),
      );
    }

    // On narrow (mobile) widths, 3 charts squeezed into one row left almost
    // no room per chart — dots were tiny and crowded. Below the breakpoint,
    // stack them full-width instead so each chart (and its dot markers) has
    // real room to breathe; on wide screens keep the 3-across row.
    Widget chartsSection = LayoutBuilder(builder: (context, constraints) {
      final charts = [
        lineCard('ERA by Game', 'era', AppColors.blueMid, 'ERA'),
        lineCard('WHIP by Game', 'whip', AppColors.perfAverage, 'WHIP'),
        lineCard('K% by Game', 'kPct', AppColors.perfExcellent, 'K_pct'),
      ];
      if (constraints.maxWidth < 700) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in charts) ...[c, const SizedBox(height: 8)],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: charts[0]),
          const SizedBox(width: 8),
          Expanded(child: charts[1]),
          const SizedBox(width: 8),
          Expanded(child: charts[2]),
        ],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filterRow,
        const SizedBox(height: 8),
        chartsSection,
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Full Game Log', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text(
                  'Each row is one game. Hold/hover a column header for the full stat name.',
                  style: TextStyle(fontSize: 11, color: AppColors.colMuted),
                ),
                const SizedBox(height: 8),
                const _GameLogColumnLegend(),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(color: AppColors.colBorder),
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppColors.blueDark),
                        children: [
                          for (final entry in _gameLogColumns)
                            _HCell(entry.short, tooltip: entry.full),
                        ],
                      ),
                      for (final row in log)
                        TableRow(children: [
                          _Cell('${row['opponent']}'),
                          _Cell('${row['gameNumber']}'),
                          _Cell('${row['ip']}'),
                          _Cell('${row['er']}'),
                          _CellColored(row['era'] != null ? (row['era'] as double).toStringAsFixed(2) : '—',
                              perfHex('ERA', row['era'] as double?)),
                          _CellColored(row['whip'] != null ? (row['whip'] as double).toStringAsFixed(3) : '—',
                              perfHex('WHIP', row['whip'] as double?)),
                          _Cell('${row['pa']}'),
                          _Cell('${row['h']}'),
                          _Cell('${row['bb']}'),
                          _Cell('${row['k']}'),
                          _CellColored(row['kPct'] != null ? '${row['kPct']}%' : '—',
                              perfHex('K_pct', row['kPct'] as double?)),
                          _CellColored(row['bbPct'] != null ? '${row['bbPct']}%' : '—',
                              perfHex('BB_pct', row['bbPct'] as double?)),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Builder(builder: (context) {
          if (!session.isPlus) return const SizedBox.shrink();
          final cd = StatsService.countApproach(data);
          final gcs = StatsService.groupedCountStats(data);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Count & Approach Snapshot', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('How counts played out across these games — see the Count & Approach tab for full detail.',
                      style: TextStyle(fontSize: 11, color: AppColors.colMuted)),
                  const SizedBox(height: 4),
                  PerfStatBar(
                    label: 'F-Strike%',
                    value: cd['fpsPct'] != null ? '${cd['fpsPct']}%' : 'N/A',
                    color: perfHex('f_strike', cd['fpsPct'] as double?),
                    scaleHint: statScaleHint('f_strike'),
                    statKey: 'f_strike',
                    rawValue: cd['fpsPct'] as double?,
                  ),
                  PerfStatBar(
                    label: 'Ahead OBP',
                    value: cd['aheadOBP'] != null ? (cd['aheadOBP'] as double).toStringAsFixed(3) : 'N/A',
                    color: perfHex('OBP_allowed', cd['aheadOBP'] as double?),
                    scaleHint: statScaleHint('OBP_allowed'),
                    statKey: 'OBP_allowed',
                    rawValue: cd['aheadOBP'] as double?,
                  ),
                  PerfStatBar(
                    label: 'Behind OBP',
                    value: cd['behindOBP'] != null ? (cd['behindOBP'] as double).toStringAsFixed(3) : 'N/A',
                    color: perfHex('OBP_allowed', cd['behindOBP'] as double?),
                    scaleHint: statScaleHint('OBP_allowed'),
                    statKey: 'OBP_allowed',
                    rawValue: cd['behindOBP'] as double?,
                  ),
                  PerfStatBar(
                    label: 'Two-Strike Count %',
                    value: gcs['twoStrikePct'] != null ? '${gcs['twoStrikePct']}%' : 'N/A',
                    color: perfHex('f_strike', gcs['twoStrikePct'] as double?),
                    scaleHint: statScaleHint('f_strike'),
                    statKey: 'f_strike',
                    rawValue: gcs['twoStrikePct'] as double?,
                  ),
                  PerfStatBar(
                    label: 'Hitter\'s Count %',
                    value: gcs['hittersCountPct'] != null ? '${gcs['hittersCountPct']}%' : 'N/A',
                    color: perfHex('BB_pct', gcs['hittersCountPct'] as double?),
                    scaleHint: statScaleHint('BB_pct'),
                    statKey: 'BB_pct',
                    rawValue: gcs['hittersCountPct'] as double?,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ColumnLabel {
  final String short;
  final String full;
  const _ColumnLabel(this.short, this.full);
}

/// Full-name definitions for every abbreviated column in the Full Game Log
/// table, used both for header tooltips and the legend beneath the title.
const List<_ColumnLabel> _gameLogColumns = [
  _ColumnLabel('Opponent', 'Opponent — the opposing team'),
  _ColumnLabel('Game', 'Game # — this game\'s number vs. that opponent'),
  _ColumnLabel('IP', 'Innings Pitched'),
  _ColumnLabel('ER', 'Earned Runs allowed'),
  _ColumnLabel('ERA', 'Earned Run Average (ER × 9 / IP)'),
  _ColumnLabel('WHIP', 'Walks + Hits per Inning Pitched'),
  _ColumnLabel('PA', 'Plate Appearances faced'),
  _ColumnLabel('H', 'Hits allowed'),
  _ColumnLabel('BB', 'Walks (Bases on Balls) allowed'),
  _ColumnLabel('K', 'Strikeouts'),
  _ColumnLabel('K%', 'Strikeout Percentage — K ÷ PA'),
  _ColumnLabel('BB%', 'Walk Percentage — BB ÷ PA'),
];

/// A compact, always-visible key for what each Full Game Log column means —
/// spelled out so the abbreviations don't require hovering/long-pressing
/// every header to decode.
class _GameLogColumnLegend extends StatelessWidget {
  const _GameLogColumnLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: _gameLogColumns
            .where((c) => c.short != 'Opponent' && c.short != 'Game')
            .map((c) => RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11, color: AppColors.colText),
                    children: [
                      TextSpan(
                          text: '${c.short}: ',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: c.full),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  final String text;
  final String? tooltip;
  const _HCell(this.text, {this.tooltip});
  @override
  Widget build(BuildContext context) {
    final cell = Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
    return tooltip == null ? cell : Tooltip(message: tooltip!, child: cell);
  }
}

class _Cell extends StatelessWidget {
  final String text;
  const _Cell(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(8), child: Text(text, style: const TextStyle(fontSize: 12)));
}

class _CellColored extends StatelessWidget {
  final String text;
  final Color color;
  const _CellColored(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        color: color,
        padding: const EdgeInsets.all(8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: (color == AppColors.perfExcellent || color == AppColors.perfPoor || color == AppColors.perfBelowAvg)
                    ? Colors.white
                    : AppColors.colText)),
      );
}
