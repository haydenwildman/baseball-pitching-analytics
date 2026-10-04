// Batting-order cycle rules (see AppSession.updateBattingOrderSlot):
//  * 10 and up keep counting until spot 1 is entered again;
//  * entering 1 starts a new cycle and the lineup length is learned from it.
//
// Run with:  flutter test test/batting_order_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pitching_analytics/services/app_session.dart';
import 'package:pitching_analytics/services/auth_service.dart';
import 'package:pitching_analytics/services/storage_service.dart';

AppSession _session() => AppSession(auth: AuthService(), storage: StorageService());

void main() {
  test('standard lineup keeps wrapping at 9', () {
    final s = _session();
    expect(s.lineupSize, 9);
  });

  test('entering 10+ means the lineup is longer than 9 and keeps counting', () {
    final s = _session();
    s.updateBattingOrderSlot(10);
    expect(s.battingOrderSlot, 10);
    expect(s.lineupSize, AppSession.openLineup); // no wrap at 9 / 10 / 11 ...
    s.updateBattingOrderSlot(13);
    expect(s.lineupSize, AppSession.openLineup);
  });

  test('entering 1 after 10+ wraps the lineup and learns its length', () {
    final s = _session();
    s.updateBattingOrderSlot(14); // 14 is due next, i.e. 13 batters so far
    s.updateBattingOrderSlot(1);
    expect(s.battingOrderSlot, 1);
    expect(s.lineupSize, 13);
  });

  test('entering 1 in an 8-man lineup shrinks the wrap point to 8', () {
    final s = _session();
    s.updateBattingOrderSlot(9); // 9 due next
    s.updateBattingOrderSlot(1);
    expect(s.lineupSize, 8);
  });

  test('re-entering a spot inside the known lineup does not change its size', () {
    final s = _session();
    s.updateBattingOrderSlot(14);
    s.updateBattingOrderSlot(1);
    expect(s.lineupSize, 13);
    s.updateBattingOrderSlot(5); // correction within the lineup
    expect(s.lineupSize, 13);
    expect(s.battingOrderSlot, 5);
  });

  test('invalid spots are ignored', () {
    final s = _session();
    s.updateBattingOrderSlot(0);
    expect(s.battingOrderSlot, 1);
  });
}
