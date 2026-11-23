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

  setUp(() {
    final items = [
      item('Rice', quantity: '5 kg', createdAt: DateTime(2026, 11, 20, 1)),
      item('Milk', quantity: '1 L', createdAt: DateTime(2026, 11, 20, 2)),
      item('Eggs', quantity: '1 tray', boughtAt: DateTime(2026, 11, 23, 9)),
    ];
    repo = InMemoryGroceryRepository(items: items);
    container = ProviderContainer(overrides: [
      groceryRepositoryProvider.overrideWithValue(repo),
      initialGroceryDataProvider.overrideWithValue(GroceryData(items: items)),
      clockProvider.overrideWithValue(() => kNow),
    ]);
    addTearDown(container.dispose);
  });

  GroceryController ctrl() =>
      container.read(groceryControllerProvider.notifier);
  GroceryItem byId(String id) =>
      container.read(groceryControllerProvider).items.firstWhere((i) => i.id == id);

  test('edit saves name, quantity and date, and persists', () async {
    final result = ctrl().editItem(
      'rice',
      name: 'Brown rice',
      quantity: '2 kg',
      plannedDate: DateTime(2026, 11, 25),
    );
    expect(result, EditItemResult.saved);
    expect(byId('rice').name, 'Brown rice');
    expect(byId('rice').quantity, '2 kg');
    // Moved from Today to Planned.
    final counts = container.read(countsProvider);
    expect((counts.today, counts.planned), (1, 1));
    await Future<void>.delayed(Duration.zero);
    expect(repo.items['rice']!.name, 'Brown rice');
  });

  test('edit rejects an empty name and changes nothing', () {
    expect(
      ctrl().editItem('rice', name: '  ', quantity: '1', plannedDate: kToday),
      EditItemResult.emptyName,
    );
    expect(byId('rice').name, 'Rice');
  });

  test('edit to an existing name on the same date needs confirmation', () {
    // Keeping its own name is never a duplicate.
    expect(
      ctrl().editItem('milk', name: 'Milk', quantity: '2 L', plannedDate: kToday),
      EditItemResult.saved,
    );
    expect(
      ctrl().editItem('rice', name: 'milk', quantity: '', plannedDate: kToday),
      EditItemResult.duplicate,
    );
    expect(byId('rice').name, 'Rice');
    expect(
      ctrl().editItem('rice',
          name: 'milk', quantity: '', plannedDate: kToday, allowDuplicate: true),
      EditItemResult.saved,
    );
  });

  test('editing a bought item keeps it bought', () {
    ctrl().editItem('eggs', name: 'Eggs', quantity: '2 trays', plannedDate: kToday);
    expect(byId('eggs').isBought, isTrue);
    expect(byId('eggs').quantity, '2 trays');
  });

  test('delete removes and undo restores in place', () async {
    final removed = ctrl().deleteItem('rice')!;
    expect(container.read(countsProvider).toBuy, 1);
    await Future<void>.delayed(Duration.zero);
    expect(repo.items.containsKey('rice'), isFalse);

    ctrl().restoreItem(removed);
    final today = container.read(toBuyGroupsProvider).single;
    expect(today.items.map((i) => i.name), ['Rice', 'Milk']);
    await Future<void>.delayed(Duration.zero);
    expect(repo.items['rice']!.quantity, '5 kg');

    // A second undo doesn't duplicate it.
    ctrl().restoreItem(removed);
    expect(container.read(countsProvider).toBuy, 2);
  });
}
