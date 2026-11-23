import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_list/data/models/grocery_item.dart';
import 'package:grocery_list/data/models/trip.dart';
import 'package:grocery_list/domain/grocery_logic.dart';

import '../support/fixtures.dart';

void main() {
  group('moving items between To buy and Bought', () {
    test('ticking moves an item to Bought and records the time', () {
      final rice = item('Rice', quantity: '5 kg');
      final ticked = toggleBought(rice, kNow);

      expect(ticked.status, ItemStatus.bought);
      expect(ticked.boughtAt, kNow);
      expect(toBuyItems([ticked]), isEmpty);
      expect(boughtItems([ticked]), [ticked]);
    });

    test('unticking moves it back to To buy and clears the time', () {
      final ticked = markBought(item('Rice'), kNow);
      final back = toggleBought(ticked, kNow);

      expect(back.status, ItemStatus.toBuy);
      expect(back.boughtAt, isNull);
      expect(toBuyItems([back]), [back]);
      expect(boughtItems([back]), isEmpty);
    });

    test('archived items stay bought and leave the Bought tab', () {
      final archived = markBought(item('Rice'), kNow).copyWith(tripId: 't1');
      expect(markToBuy(archived).isBought, isTrue);
      expect(boughtItems([archived]), isEmpty);
    });
  });

  group('grouping by planned date', () {
    test('Today comes first, then future dates ascending', () {
      final items = [
        item('Bananas', planned: DateTime(2026, 11, 27)),
        item('Oil', planned: DateTime(2026, 11, 25)),
        item('Rice'),
        item('Milk'),
      ];
      final groups = groupToBuyByPlannedDate(items, kNow);

      expect(groups.map((g) => g.date), [
        DateTime(2026, 11, 23),
        DateTime(2026, 11, 25),
        DateTime(2026, 11, 27),
      ]);
      expect(groups.first.isToday, isTrue);
      expect(groups.skip(1).every((g) => !g.isToday), isTrue);
      expect(groups.first.items.map((i) => i.name), ['Rice', 'Milk']);
    });

    test('future items are not counted as today until their date', () {
      final items = [
        item('Rice'),
        item('Oil', planned: DateTime(2026, 11, 25)),
        item('Bananas', planned: DateTime(2026, 11, 25)),
      ];
      expect(countToBuyToday(items, kNow), 1);
      expect(countPlanned(items, kNow), 2);

      final wed = DateTime(2026, 11, 25, 9);
      expect(countToBuyToday(items, wed), 3);
      expect(countPlanned(items, wed), 0);
    });

    test('overdue unbought items roll into Today', () {
      final groups = groupToBuyByPlannedDate(
        [item('Eggs', planned: DateTime(2026, 11, 20))],
        kNow,
      );
      expect(groups.single.isToday, isTrue);
      expect(groups.single.date, kToday);
    });

    test('bought items group by bought date, newest first', () {
      final items = [
        item('Eggs', boughtAt: DateTime(2026, 11, 23, 9)),
        item('Bread', boughtAt: DateTime(2026, 11, 23, 10)),
        item('Coffee', boughtAt: DateTime(2026, 11, 22, 18)),
        item('Rice'),
      ];
      final groups = groupBoughtByDate(items, kNow);

      expect(groups.map((g) => g.date), [kToday, DateTime(2026, 11, 22)]);
      expect(groups.first.isToday, isTrue);
      expect(groups.first.items.map((i) => i.name), ['Bread', 'Eggs']);
    });
  });

  group('saving a trip', () {
    test("archives today's bought items into one trip", () {
      final items = [
        item('Eggs', boughtAt: DateTime(2026, 11, 23, 9)),
        item('Garlic', boughtAt: DateTime(2026, 11, 23, 9, 5)),
        item('Coffee', boughtAt: DateTime(2026, 11, 22, 18)),
        item('Rice'),
      ];
      final result = saveTodayAsTrip(items, kNow, sequentialIds('trip'))!;

      expect(result.trip.id, 'trip-1');
      expect(result.trip.date, kToday);
      expect(result.trip.itemIds, ['eggs', 'garlic']);
      expect(result.archivedItems.every((i) => i.tripId == 'trip-1'), isTrue);

      final after = [
        ...result.archivedItems,
        ...items.where((i) => !result.trip.itemIds.contains(i.id)),
      ];
      // Cleared from the Bought tab; yesterday's unsaved item stays.
      expect(boughtItems(after).map((i) => i.name), ['Coffee']);
      expect(toBuyItems(after).map((i) => i.name), ['Rice']);
    });

    test('returns null when nothing was bought today', () {
      expect(saveTodayAsTrip([item('Rice')], kNow, sequentialIds()), isNull);
    });
  });

  group('copying a trip back to To buy', () {
    final trip = Trip(
      id: 't1',
      date: DateTime(2026, 11, 22),
      itemIds: const ['onions', 'oil', 'coffee'],
      createdAt: DateTime(2026, 11, 22, 18),
    );
    final archived = [
      item('Onions', quantity: '1 kg', boughtAt: DateTime(2026, 11, 22, 17), tripId: 't1'),
      item('Oil', quantity: '1 L', boughtAt: DateTime(2026, 11, 22, 17), tripId: 't1'),
      item('Coffee', quantity: '200 g', boughtAt: DateTime(2026, 11, 22, 17), tripId: 't1'),
    ];

    test('creates fresh to-buy items planned for today', () {
      final copies = copyTripToToday(trip, archived, kNow, sequentialIds('new'));

      expect(copies.map((i) => i.name), ['Onions', 'Oil', 'Coffee']);
      expect(copies.map((i) => i.quantity), ['1 kg', '1 L', '200 g']);
      expect(copies.every((i) => i.status == ItemStatus.toBuy), isTrue);
      expect(copies.every((i) => i.plannedDate == kToday), isTrue);
      expect(copies.every((i) => i.tripId == null && i.boughtAt == null), isTrue);
      expect(copies.map((i) => i.id), ['new-1', 'new-2', 'new-3']);
      // Originals are untouched (history keeps them).
      expect(archived.every((i) => i.tripId == 't1'), isTrue);
      // They show up under Today, in trip order.
      final today = groupToBuyByPlannedDate([...archived, ...copies], kNow);
      expect(today.single.items.map((i) => i.name), ['Onions', 'Oil', 'Coffee']);
    });

    test("skips names already on today's list", () {
      final existing = item('coffee', id: 'existing');
      final copies = copyTripToToday(
        trip,
        [...archived, existing],
        kNow,
        sequentialIds(),
      );
      expect(copies.map((i) => i.name), ['Onions', 'Oil']);
    });
  });

  group('entry parsing and validation', () {
    test('splits a trailing quantity from the name', () {
      ParsedEntry p(String s) => parseEntry(s)!;
      expect(p('Rice 5 kg').name, 'Rice');
      expect(p('Rice 5 kg').quantity, '5 kg');
      expect(p('Chicken thighs 1 kg').name, 'Chicken thighs');
      expect(p('Bananas 1 bunch').quantity, '1 bunch');
      expect(p('Coffee 200g').quantity, '200g');
      expect(p('  Milk  ').name, 'Milk');
      expect(p('Milk').quantity, '');
    });

    test('rejects empty names', () {
      expect(parseEntry(''), isNull);
      expect(parseEntry('   '), isNull);
    });

    test('detects duplicates on the same date only', () {
      final items = [item('Rice'), item('Oil', planned: DateTime(2026, 11, 25))];
      expect(hasDuplicateOnDate(items, ' rice ', kToday, kNow), isTrue);
      expect(hasDuplicateOnDate(items, 'Rice', DateTime(2026, 11, 25), kNow), isFalse);
      expect(hasDuplicateOnDate(items, 'oil', DateTime(2026, 11, 25), kNow), isTrue);
    });
  });

  group('history', () {
    final items = [
      item('Eggs', boughtAt: DateTime(2026, 11, 23, 9), tripId: 'a'),
      item('Rice', boughtAt: DateTime(2026, 11, 21, 9), tripId: 'b'),
      item('Soy sauce', boughtAt: DateTime(2026, 11, 21, 9), tripId: 'b'),
      item('Old', boughtAt: DateTime(2026, 10, 1, 9), tripId: 'c'),
    ];
    final trips = [
      Trip(id: 'b', date: DateTime(2026, 11, 21), itemIds: const ['rice', 'soy-sauce'], createdAt: DateTime(2026, 11, 21, 10)),
      Trip(id: 'a', date: kToday, itemIds: const ['eggs'], createdAt: kNow),
      Trip(id: 'c', date: DateTime(2026, 10, 1), itemIds: const ['old'], createdAt: DateTime(2026, 10, 1)),
    ];

    test('newest first, last 30 days only', () {
      final views = historyTrips(trips, items, kNow);
      expect(views.map((v) => v.trip.id), ['a', 'b']);
      expect(views[1].totalCount, 2);
    });

    test('search filters rows by item name', () {
      final views = historyTrips(trips, items, kNow, query: 'SOY');
      expect(views.single.trip.id, 'b');
      expect(views.single.items.map((i) => i.name), ['Soy sauce']);
      expect(views.single.totalCount, 2);
    });
  });
}
