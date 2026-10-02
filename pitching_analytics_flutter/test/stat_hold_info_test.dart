import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitching_analytics/widgets/stat_vbox.dart';

void main() {
  const desc = 'Calculation: Walks / PA x 100\n\nWalk Percentage.';

  Widget host(Alignment where) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667)),
          child: Scaffold(
            body: Align(
              alignment: where,
              child: const SizedBox(
                width: 110,
                child: StatVBox(label: 'BB%', value: '8.1%', description: desc),
              ),
            ),
          ),
        ),
      );

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    for (final where in [Alignment.topLeft, Alignment.bottomRight, Alignment.center]) {
      testWidgets('hold shows, release hides ($kind, $where)', (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(where));

        expect(find.byType(InkWell), findsNothing); // no "i" button
        expect(find.text('i'), findsNothing);
        expect(find.textContaining('Walk Percentage'), findsNothing);

        final g = await tester.startGesture(tester.getCenter(find.byType(StatVBox)), kind: kind);
        await tester.pump(const Duration(milliseconds: 700));
        final popup = find.textContaining('Walk Percentage');
        expect(popup, findsOneWidget);

        final r = tester.getRect(find.ancestor(of: popup, matching: find.byType(DecoratedBox)).first);
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(375));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(667));

        await g.up();
        await tester.pump();
        expect(find.textContaining('Walk Percentage'), findsNothing);
      });
    }
  }

  testWidgets('dragging (scrolling) does not open the popup', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: const [
          StatVBox(label: 'BB%', value: '8.1%', description: desc),
          SizedBox(height: 1500),
        ]),
      ),
    ));
    await tester.drag(find.byType(StatVBox), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.textContaining('Walk Percentage'), findsNothing);
  });
}
