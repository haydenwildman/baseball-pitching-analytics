import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/baseball_field_painter.dart';

/// Port of the R app's "Edit At-Bats" tab: pick a ball-in-play row from a
/// list, then tap the field to set/adjust its spray-chart landing spot.
class EditAtBatsScreen extends StatefulWidget {
  const EditAtBatsScreen({super.key});

  @override
  State<EditAtBatsScreen> createState() => _EditAtBatsScreenState();
}

class _EditAtBatsScreenState extends State<EditAtBatsScreen> {
  int? _selectedIndex;
  double? _pendingX;
  double? _pendingY;
  String _battedType = 'gb';

  static const bipOutcomes = {
    '1b', '2b', '3b', 'hr', 'go', 'fo', 'lo', 'dp', 'e', 'fc'
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final candidates = <int>[];
    for (int i = 0; i < session.pitches.length; i++) {
      if (bipOutcomes.contains(session.pitches[i].outcome)) candidates.add(i);
    }

    return ResponsiveRow(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select At-Bat', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: Responsive.isPhone(context) ? 280 : 480,
                    child: candidates.isEmpty
                        ? const Center(
                            child: Text('No balls-in-play logged yet.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: candidates.length,
                            itemBuilder: (context, idx) {
                              final ri = candidates[idx];
                              final row = session.pitches[ri];
                              final selected = _selectedIndex == ri;
                              final hasSpray = row.xCoord != null && row.yCoord != null;
                              return InkWell(
                                onTap: () => setState(() {
                                  _selectedIndex = ri;
                                  _pendingX = row.xCoord;
                                  _pendingY = row.yCoord;
                                  _battedType = row.battedType ?? 'gb';
                                }),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.blueDark : Colors.white,
                                    border: Border.all(color: AppColors.colBorder, width: 2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Text('${idx + 1}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: selected ? Colors.white : AppColors.colText)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${row.game} G${row.gameNumber} | #${row.batterNumber}',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: selected ? Colors.white : AppColors.colText)),
                                            Text('${row.pitchType} / ${row.outcome}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: selected ? Colors.white70 : Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        hasSpray
                                            ? Icons.check_circle_outline
                                            : Icons.remove_circle_outline,
                                        size: 16,
                                        color: hasSpray
                                            ? AppColors.perfExcellent
                                            : AppColors.colMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 7,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Selected At-Bat', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_selectedIndex == null)
                    const Text('Tap a row to select.', style: TextStyle(color: Colors.grey))
                  else ...[
                    DropdownButtonFormField<String>(
                      value: _battedType,
                      decoration: const InputDecoration(labelText: 'Batted Type'),
                      items: const [
                        DropdownMenuItem(value: 'gb', child: Text('Ground Ball')),
                        DropdownMenuItem(value: 'ld', child: Text('Line Drive')),
                        DropdownMenuItem(value: 'fb', child: Text('Fly Ball')),
                      ],
                      onChanged: (v) => setState(() => _battedType = v!),
                    ),
                    const SizedBox(height: 8),
                    const Text('Click field to mark landing spot:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (layoutCtx, constraints) {
                          final size = constraints.biggest;
                          return SprayFieldSurface(
                            sprayPoints: const [],
                            highlightX: _pendingX,
                            highlightY: _pendingY,
                            onTapDown: (details) {
                              final field =
                                  FieldCoordConverter.canvasToField(details.localPosition, size);
                              setState(() {
                                _pendingX = field.dx;
                                _pendingY = field.dy;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_pendingX == null
                        ? 'Click field to set location'
                        : 'New: (${_pendingX!.round()}, ${_pendingY!.round()})'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.colSuccess),
                          onPressed: () async {
                            final row = session.pitches[_selectedIndex!];
                            final updated = row.copyWith(
                              xCoord: _pendingX,
                              yCoord: _pendingY,
                              battedType: _battedType,
                            );
                            await session.updatePitchAt(_selectedIndex!, updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('Saved!')));
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.colError),
                          onPressed: () => setState(() {
                            _pendingX = null;
                            _pendingY = null;
                          }),
                          child: const Text('Clear Spray'),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
