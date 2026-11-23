import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_list/data/models/grocery_item.dart';
import 'package:grocery_list/data/repositories/in_memory_grocery_repository.dart';
import 'package:grocery_list/state/grocery_controller.dart';
import 'package:grocery_list/state/selectors.dart';

import '../support/fixtures.dart';

void main() {
  late InMemoryGroceryRepository repo;
  late ProviderContainer container;
  late DateTime now;

  ProviderContainer makeContainer(List<GroceryItem> items) {
    repo = InMemoryGroceryRepository(items: items);
    final c = ProviderContainer(overrides: [
      groceryRepositoryProvider.overrideWithValue(repo),
      initialGroceryDataProvider.overrideWithValue(GroceryData(items: items)),
      clockProvider.overrideWithValue(() => now),
      idGeneratorProvider.overrideWithValue(sequentialIds()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  GroceryController ctrl() => container.read(groceryControllerProvider.notifier);

  setUp(() {
    now = kNow;
    container = makeContainer([
      item('Rice', quantity: '5 kg'),
      item('Oil', planned: DateTime(2026, 11, 25)),
    ]);
  });

  test('add parses quantity, persists, and rejects empty names', () async {
    expect(ctrl().addItem('Milk 1 L', kToday), AddItemResult.added);
    expect(ctrl().addItem('   ', kToday), AddItemResult.emptyName);
    await Future<void>.delayed(Duration.zero);

    final milk = repo.items['id-1']!;
    expect(milk.name, 'Milk');
    expect(milk.quantity, '1 L');
    expect(container.read(countsProvider).today, 2);
  });

  test('duplicate on the same date needs confirmation', () {
    expect(ctrl().addItem('rice', kToday), AddItemResult.duplicate);
    expect(container.read(countsProvider).toBuy, 2);
    expect(ctrl().addItem('rice', kToday, allowDuplicate: true),
        AddItemResult.added);
    expect(ctrl().addItem('Rice', DateTime(2026, 11, 24)), AddItemResult.added);
    expect(container.read(countsProvider).toBuy, 4);
  });

  test('toggle updates counts live and writes through', () async {
    ctrl().toggleBought('rice');
    var counts = container.read(countsProvider);
    expect((counts.toBuy, counts.bought, counts.today, counts.planned),
        (1, 1, 0, 1));
    await Future<void>.delayed(Duration.zero);
    expect(repo.items['rice']!.boughtAt, kNow);

    ctrl().toggleBought('rice');
    counts = container.read(countsProvider);
    expect((counts.toBuy, counts.bought), (2, 0));
  });

  test('save trip clears Bought; buy again restores to today', () async {
    ctrl().toggleBought('rice');
    final trip = ctrl().saveTrip()!;
    expect(container.read(countsProvider).bought, 0);
    expect(container.read(historyProvider).single.trip.id, trip.id);
    await Future<void>.delayed(Duration.zero);
    expect(repo.trips[trip.id]!.itemIds, ['rice']);

    // Next day: buy again.
    now = DateTime(2026, 11, 24, 8);
    expect(ctrl().buyAgain(trip.id), 1);
    final todayGroup = container.read(toBuyGroupsProvider).first;
    expect(todayGroup.isToday, isTrue);
    expect(todayGroup.items.single.name, 'Rice');
    expect(todayGroup.items.single.plannedDate, DateTime(2026, 11, 24));
  });

  test('save trip with nothing bought returns null', () {
    expect(ctrl().saveTrip(), isNull);
  });
}
