import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_list/app.dart';
import 'package:grocery_list/data/models/grocery_item.dart';
import 'package:grocery_list/data/repositories/in_memory_grocery_repository.dart';
import 'package:grocery_list/state/grocery_controller.dart';

import '../support/fixtures.dart';

Future<InMemoryGroceryRepository> pumpApp(
  WidgetTester tester,
  List<GroceryItem> items,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = InMemoryGroceryRepository(items: items);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      groceryRepositoryProvider.overrideWithValue(repo),
      initialGroceryDataProvider.overrideWithValue(GroceryData(items: items)),
      clockProvider.overrideWithValue(() => kNow),
      idGeneratorProvider.overrideWithValue(sequentialIds('new')),
    ],
    child: const GroceryApp(),
  ));
  await tester.pumpAndSettle();
  return repo;
}

List<GroceryItem> seed() => [
      item('Rice', quantity: '5 kg', createdAt: DateTime(2026, 11, 20, 1)),
      item('Milk', quantity: '1 L', createdAt: DateTime(2026, 11, 20, 2)),
      item('Cooking oil', quantity: '1 L', planned: DateTime(2026, 11, 25)),
      item('Eggs', quantity: '1 tray', boughtAt: DateTime(2026, 11, 23, 9)),
    ];

TextStyle? styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style;

void main() {
  testWidgets('header and tab counts match the data', (tester) async {
    await pumpApp(tester, seed());

    expect(find.text('Mon, Nov 23'), findsWidgets);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('2 to buy today · 1 planned'), findsOneWidget);
    expect(find.text('To buy · 3'), findsOneWidget);
    expect(find.text('Bought · 1'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('PLANNED'), findsOneWidget);
    expect(find.text('Wed, Nov 25'), findsOneWidget);
  });

  testWidgets('switching tabs shows To buy or Bought items', (tester) async {
    await pumpApp(tester, seed());

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Eggs'), findsNothing);

    await tester.tap(find.text('Bought · 1'));
    await tester.pumpAndSettle();
    expect(find.text('BOUGHT TODAY'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    expect(styleOf(tester, 'Eggs')!.decoration, TextDecoration.lineThrough);

    await tester.tap(find.text('To buy · 3'));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Eggs'), findsNothing);
  });

  testWidgets('checkbox moves an item to Bought and back', (tester) async {
    final repo = await pumpApp(tester, seed());

    await tester.tap(find.byKey(const ValueKey('check-rice')));
    await tester.pumpAndSettle();
    expect(find.text('To buy · 2'), findsOneWidget);
    expect(find.text('Bought · 2'), findsOneWidget);
    expect(find.text('1 to buy today · 1 planned'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    expect(repo.items['rice']!.boughtAt, kNow);

    await tester.tap(find.text('Bought · 2'));
    await tester.pumpAndSettle();
    expect(styleOf(tester, 'Rice')!.decoration, TextDecoration.lineThrough);
    final box = tester.widget<Checkbox>(find.byKey(const ValueKey('check-rice')));
    expect(box.value, isTrue);

    // Uncheck from the Bought tab: back to To buy.
    await tester.tap(find.byKey(const ValueKey('check-rice')));
    await tester.pumpAndSettle();
    expect(find.text('To buy · 3'), findsOneWidget);
    expect(find.text('Bought · 1'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    expect(repo.items['rice']!.boughtAt, isNull);
  });

  testWidgets('add row parses quantity and confirms duplicates',
      (tester) async {
    await pumpApp(tester, seed());

    await tester.tap(find.byKey(const ValueKey('add-button')));
    await tester.pump();
    expect(find.text('Type an item name first.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('add-field')), 'Tomatoes 1 kg');
    await tester.tap(find.byKey(const ValueKey('add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('To buy · 4'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('add-field')), 'rice');
    await tester.tap(find.byKey(const ValueKey('add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Add "rice" again?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('To buy · 4'), findsOneWidget);
  });

  testWidgets('save trip, view history, buy again', (tester) async {
    await pumpApp(tester, seed());

    await tester.tap(find.text('Save trip to history'));
    await tester.pumpAndSettle();
    expect(find.text('Bought · 0'), findsOneWidget);
    expect(find.text('Trip saved · 1 item'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Purchase history'), findsOneWidget);
    expect(find.text('Today, Mon Nov 23'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('history-search')), 'zzz');
    await tester.pump();
    expect(find.text('Eggs'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('history-search')), 'egg');
    await tester.pump();
    expect(find.text('Eggs'), findsOneWidget);

    await tester.tap(find.text('Buy again from last trip'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('To buy · 4'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
  });
}
