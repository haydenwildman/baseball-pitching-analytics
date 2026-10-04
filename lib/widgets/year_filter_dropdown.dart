import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_session.dart';

/// A small "Year" dropdown that filters every stats screen down to a
/// single season. Drop this into any screen's filter row — it reads
/// and writes `AppSession.selectedYear` directly, so every screen stays
/// in sync with the same choice.
class YearFilterDropdown extends StatelessWidget {
  const YearFilterDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final years = session.availableYears;

    return SizedBox(
      width: 110,
      child: DropdownButtonFormField<int?>(
        isExpanded: true,
        value: session.selectedYear,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Year'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('All', overflow: TextOverflow.ellipsis)),
          for (final y in years)
            DropdownMenuItem<int?>(value: y, child: Text('$y', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => session.setSelectedYear(v),
      ),
    );
  }
}
