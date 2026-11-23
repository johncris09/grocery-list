import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'groceries_screen_test.dart' show pumpApp, seed;

double rowTop(WidgetTester tester, String name) =>
    tester.getTopLeft(find.text(name)).dy;

void main() {
  testWidgets('to-buy rows have grips; bought rows do not', (tester) async {
    await pumpApp(tester, seed());

    expect(find.byKey(const ValueKey('grip-rice')), findsOneWidget);
    expect(find.byKey(const ValueKey('grip-cooking-oil')), findsOneWidget);
    expect(find.textContaining('Drag ⋮⋮ to reorder'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.byKey(const ValueKey('grip-eggs')), findsNothing);
  });

  testWidgets('dragging the grip reorders and persists', (tester) async {
    final repo = await pumpApp(tester, seed());
    expect(rowTop(tester, 'Rice'), lessThan(rowTop(tester, 'Milk')));

    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey('grip-milk'))));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(rowTop(tester, 'Milk'), lessThan(rowTop(tester, 'Rice')));
    expect(repo.items['milk']!.sortOrder, 0);
    expect(repo.items['rice']!.sortOrder, 1);
    // Tapping the grip area must not have ticked anything off.
    expect(find.text('To buy · 3'), findsOneWidget);
  });

  testWidgets('tapping the row still toggles bought', (tester) async {
    await pumpApp(tester, seed());
    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    expect(find.text('To buy · 2'), findsOneWidget);
  });
}
