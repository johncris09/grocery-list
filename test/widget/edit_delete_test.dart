import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'groceries_screen_test.dart' show pumpApp, seed;

void main() {
  testWidgets('long-press opens the edit sheet and saves changes',
      (tester) async {
    final repo = await pumpApp(tester, seed());

    await tester.longPress(find.text('Rice'));
    await tester.pumpAndSettle();
    expect(find.text('Edit item'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Rice'), findsOneWidget);
    expect(find.widgetWithText(TextField, '5 kg'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('edit-name')), 'Brown rice');
    await tester.enterText(find.byKey(const ValueKey('edit-qty')), '2 kg');
    await tester.tap(find.byKey(const ValueKey('edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsNothing);
    expect(find.text('Brown rice'), findsOneWidget);
    expect(find.text('2 kg'), findsOneWidget);
    expect(repo.items['rice']!.name, 'Brown rice');
  });

  testWidgets('empty name shows an error and keeps the sheet open',
      (tester) async {
    await pumpApp(tester, seed());

    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('edit-name')), '   ');
    await tester.tap(find.byKey(const ValueKey('edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Edit item'), findsOneWidget);
  });

  testWidgets('Delete in the sheet removes the item; Undo brings it back',
      (tester) async {
    await pumpApp(tester, seed());

    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsNothing);
    expect(find.text('To buy · 2'), findsOneWidget);
    expect(find.text('"Milk" deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('To buy · 3'), findsOneWidget);
  });

  testWidgets('swipe left deletes with Undo, and the snackbar auto-hides',
      (tester) async {
    await pumpApp(tester, seed());

    await tester.drag(find.text('Rice'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsNothing);
    expect(find.text('"Rice" deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('"Rice" deleted'), findsNothing);
    expect(find.text('To buy · 2'), findsOneWidget);
  });
}
