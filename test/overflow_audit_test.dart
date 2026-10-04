// Overflow audit for shared components: long labels / values and tiny bar
// fractions must never raise RenderFlex overflow errors at any width.
//
// Run with:  flutter test test/overflow_audit_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitching_analytics/theme/app_theme.dart';
import 'package:pitching_analytics/widgets/stat_vbox.dart';
import 'package:pitching_analytics/widgets/value_bar.dart';

const _widths = <double>[1440, 768, 430, 320];

Future<void> _pump(WidgetTester t, double w, Widget child) async {
  t.view.physicalSize = Size(w, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: child)),
  ));
  await t.pumpAndSettle();
}

void main() {
  for (final w in _widths) {
    testWidgets('ValueBar keeps its label inside at ${w.toInt()}px', (t) async {
      await _pump(
        t,
        w,
        Column(children: const [
          ValueBar(fraction: 0.0, color: AppColors.perfPoor, text: 'N/A'),
          SizedBox(height: 8),
          ValueBar(fraction: 0.02, color: AppColors.perfPoor, text: '12.345%'),
          SizedBox(height: 8),
          ValueBar(fraction: 0.5, color: AppColors.perfGood, text: '1.234'),
          SizedBox(height: 8),
          ValueBar(fraction: 1.0, color: AppColors.perfExcellent, text: '100%'),
        ]),
      );
      expect(t.takeException(), isNull);
      // the label sits within its bar
      final bar = t.getRect(find.byType(ValueBar).at(1));
      final label = t.getRect(find.text('12.345%'));
      expect(label.right, lessThanOrEqualTo(bar.right + 0.5));
    });

    testWidgets('PerfStatBar with tiny / missing values at ${w.toInt()}px', (t) async {
      await _pump(
        t,
        w,
        Column(children: [
          PerfStatBar(label: 'A very long statistic label that needs to wrap nicely', value: '0.05', color: AppColors.perfPoor, statKey: 'ERA', rawValue: 0.05),
          PerfStatBar(label: 'AVG Against', value: 'N/A', color: AppColors.colBorder),
          const PerfStatBar(label: 'IP', value: '12.1', color: AppColors.tint),
        ]),
      );
      expect(t.takeException(), isNull);
    });
  }
}
