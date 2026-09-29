import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/pitch_event.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';

/// Direct CSV-style editor — port of the R app's "Edit Raw Data" DT table.
/// Tap the pencil to edit a row in place, the trash icon to delete it, or
/// "+ Add Row" to log a pitch manually without going through Game Input.
class EditRawDataScreen extends StatefulWidget {
  const EditRawDataScreen({super.key});

  @override
  State<EditRawDataScreen> createState() => _EditRawDataScreenState();
}

class _EditRawDataScreenState extends State<EditRawDataScreen> {
  static const _uuid = Uuid();
  static const handOptions = ['L', 'R', 'S'];
  static const eventTypeOptions = ['pitch', 'po', 'to', 'txo', 'bk'];
  static const _builtInPitchTypes = ['fb', 'cv', 'ch', 'sl'];
  static const callOptions = ['b', 'ss', 'sl', 'f', 'ip', 'hbp', 'dk'];
  static const outcomeOptions = [
    '', '1b', '2b', '3b', 'hr', 'go', 'fo', 'lo', 'dp', 'e', 'fc', 'bb',
    'hbp', 'k', 'kl', 'dk', 'po_out', 'po_safe', 'to', 'txo', 'bk'
  ];

  /// Opens the Add/Edit row dialog.
  /// - [existing] + [index]: edit that row in place.
  /// - [insertIndex] (new row only): insert the new row at that position
  ///   in the log instead of appending it to the end.
  Future<void> _openRowDialog(BuildContext context,
      {PitchEvent? existing, int? index, int? insertIndex}) async {
    final session = context.read<AppSession>();
    final isNew = existing == null;

    // Built-in codes + any custom pitch buttons the user has added + any
    // pitch type codes already present in the data (covers legacy 'other'
    // rows or custom codes typed before this dropdown existed).
    final pitchTypeOptions = <String>{
      ..._builtInPitchTypes,
      ...session.customPitchTypes.map((c) => c.toLowerCase()),
      ...session.pitches.map((p) => (p.pitchType ?? '').toLowerCase()).where((s) => s.isNotEmpty),
    }.toList()
      ..sort();

    final gameCtrl = TextEditingController(text: existing?.game ?? session.currentOpponent);
    final gameNumCtrl = TextEditingController(text: '${existing?.gameNumber ?? session.currentGameNumber}');
    final batterCtrl = TextEditingController(text: '${existing?.batter ?? session.completedPAs}');
    final jerseyCtrl = TextEditingController(text: '${existing?.batterNumber ?? ''}');
    final orderCtrl = TextEditingController(text: '${existing?.battingOrder ?? 1}');
    final pitchNumCtrl = TextEditingController(text: '${existing?.pitchNum ?? 1}');
    final outsCtrl = TextEditingController(text: '${existing?.outs ?? 0}');
    final erCtrl = TextEditingController(text: '${existing?.er ?? 0}');
    final seasonCtrl = TextEditingController(text: '${existing?.season ?? DateTime.now().year}');

    String hand = existing?.hand ?? 'R';
    String eventType = existing?.eventType ?? 'pitch';
    String pitchType = existing?.pitchType ?? 'fb';
    String call = existing?.call ?? 'ip';
    String outcome = existing?.outcome ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        Widget field(String label, TextEditingController c, {TextInputType? kb}) => SizedBox(
              width: 130,
              child: TextField(
                controller: c,
                keyboardType: kb,
                decoration: InputDecoration(labelText: label),
              ),
            );
        Widget dropdown(String label, String value, List<String> opts, ValueChanged<String> onChanged) =>
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(labelText: label),
                items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '(none)' : o))).toList(),
                onChanged: (v) => setDialogState(() => onChanged(v!)),
              ),
            );

        return AlertDialog(
          title: Text(isNew
              ? (insertIndex != null ? 'Insert Row Here' : 'Add Row')
              : 'Edit Row'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  field('Opponent', gameCtrl),
                  field('Game #', gameNumCtrl, kb: TextInputType.number),
                  field('Year', seasonCtrl, kb: TextInputType.number),
                  field('Batter Seq', batterCtrl, kb: TextInputType.number),
                  field('Jersey #', jerseyCtrl, kb: TextInputType.number),
                  field('Order (1-9)', orderCtrl, kb: TextInputType.number),
                  dropdown('Hand', hand, handOptions, (v) => hand = v),
                  dropdown('Event Type', eventType, eventTypeOptions, (v) => eventType = v),
                  field('Pitch # in AB', pitchNumCtrl, kb: TextInputType.number),
                  dropdown('Pitch Type', pitchType, pitchTypeOptions, (v) => pitchType = v),
                  dropdown('Call', call, callOptions, (v) => call = v),
                  dropdown('Outcome', outcome, outcomeOptions, (v) => outcome = v),
                  field('Outs', outsCtrl, kb: TextInputType.number),
                  field('ER', erCtrl, kb: const TextInputType.numberWithOptions(decimal: true)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final event = PitchEvent(
                  id: existing?.id ?? _uuid.v4(),
                  userId: session.currentUser!.id,
                  game: gameCtrl.text.trim().isEmpty ? 'Unknown' : gameCtrl.text.trim(),
                  gameNumber: int.tryParse(gameNumCtrl.text) ?? 1,
                  batter: int.tryParse(batterCtrl.text) ?? 1,
                  batterNumber: int.tryParse(jerseyCtrl.text),
                  battingOrder: int.tryParse(orderCtrl.text) ?? 1,
                  hand: hand,
                  eventType: eventType,
                  pitchNum: int.tryParse(pitchNumCtrl.text) ?? 1,
                  pitchType: pitchType,
                  call: call,
                  outcome: outcome.isEmpty ? null : outcome,
                  ab: (outcome.isNotEmpty && !{'bb', 'hbp'}.contains(outcome)) ? 1 : 0,
                  outs: int.tryParse(outsCtrl.text) ?? 0,
                  er: double.tryParse(erCtrl.text) ?? 0,
                  xCoord: existing?.xCoord,
                  yCoord: existing?.yCoord,
                  battedType: existing?.battedType,
                  inning: existing?.inning,
                  paId: existing?.paId ?? 0,
                  season: int.tryParse(seasonCtrl.text) ?? DateTime.now().year,
                  timestamp: existing?.timestamp,
                );
                if (isNew) {
                  if (insertIndex != null) {
                    await session.insertPitchAt(insertIndex, event);
                  } else {
                    await session.addManualPitch(event);
                  }
                } else {
                  await session.updatePitchAt(index!, event);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isNew ? (insertIndex != null ? 'Insert' : 'Add') : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final session = context.read<AppSession>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ALL pitches?'),
        content: Text(
          'This permanently removes all ${session.pitches.length} rows — every pitch, '
          'pickoff, and throwout logged for this account, whether it came from Game '
          'Input or was typed in here. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: AppColors.colError)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await session.deleteAllPitches();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All pitches deleted.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final data = session.pitches;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Direct Pitch Log Editor', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${data.length} rows logged', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            // ── Actions row — Add Row and Delete All live together here,
            // right above the table they act on, instead of Add Row being
            // stranded up in the title bar.
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openRowDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Row (end)'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.colSuccess),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openRowDialog(context, insertIndex: 0),
                  icon: const Icon(Icons.vertical_align_top, size: 16),
                  label: const Text('Insert at Top'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: data.isEmpty ? null : () => _confirmDeleteAll(context),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Delete All'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.colError),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (data.isEmpty)
              const Text('No data yet.', style: TextStyle(color: Colors.grey))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(AppColors.blueDark),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  columns: const [
                    DataColumn(label: Text('Year')),
                    DataColumn(label: Text('Game')),
                    DataColumn(label: Text('G#')),
                    DataColumn(label: Text('Batter')),
                    DataColumn(label: Text('Jersey')),
                    DataColumn(label: Text('Order')),
                    DataColumn(label: Text('Hand')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Pitch')),
                    DataColumn(label: Text('Call')),
                    DataColumn(label: Text('Outcome')),
                    DataColumn(label: Text('Outs')),
                    DataColumn(label: Text('ER')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (int i = 0; i < data.length; i++)
                      DataRow(cells: [
                        DataCell(Text('${data[i].season}')),
                        DataCell(Text(data[i].game)),
                        DataCell(Text('${data[i].gameNumber}')),
                        DataCell(Text('${data[i].batter}')),
                        DataCell(Text('${data[i].batterNumber ?? "-"}')),
                        DataCell(Text('${data[i].battingOrder}')),
                        DataCell(Text(data[i].hand)),
                        DataCell(Text(data[i].eventType)),
                        DataCell(Text((data[i].pitchType ?? '').toUpperCase())),
                        DataCell(Text(data[i].call ?? '')),
                        DataCell(Text(data[i].outcome ?? '')),
                        DataCell(Text('${data[i].outs}')),
                        DataCell(Text('${data[i].er}')),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Insert row below this one',
                            icon: const Icon(Icons.playlist_add, size: 18),
                            onPressed: () => _openRowDialog(context, insertIndex: i + 1),
                          ),
                          IconButton(
                            tooltip: 'Edit row',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _openRowDialog(context, existing: data[i], index: i),
                          ),
                          IconButton(
                            tooltip: 'Delete row',
                            icon: const Icon(Icons.delete_outline, color: AppColors.colError, size: 18),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete row?'),
                                  content: const Text(
                                      'This permanently removes this pitch, whether it was '
                                      'logged from Game Input or added here.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await context.read<AppSession>().deletePitchAt(i);
                              }
                            },
                          ),
                        ])),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
