import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_list/data/models/grocery_item.dart';
import 'package:grocery_list/domain/grocery_logic.dart';

import '../support/fixtures.dart';

List<String> names(List<GroceryItem> items) => [for (final i in items) i.name];

List<String> todaySection(List<GroceryItem> items) =>
    names(groupToBuyByPlannedDate(items, kToday).first.items);

/// Applies [updated] on top of [items] (what the controller does).
List<GroceryItem> apply(List<GroceryItem> items, List<GroceryItem> updated) {
  final byId = {for (final i in updated) i.id: i};
  return [for (final i in items) byId[i.id] ?? i];
}

void main() {
  final base = [
    item('Rice', createdAt: DateTime(2026, 11, 20, 1)),
    item('Milk', createdAt: DateTime(2026, 11, 20, 2)),
    item('Eggs', createdAt: DateTime(2026, 11, 20, 3)),
  ];

  test('untouched items keep creation order', () {
    expect(todaySection(base), ['Rice', 'Milk', 'Eggs']);
  });

  test('reorderSection moves down and renumbers the section', () {
    final updated = reorderSection(base, 0, 2);
    final items = apply(base, updated);
    expect(todaySection(items), ['Milk', 'Eggs', 'Rice']);
    expect([for (final i in items) i.sortOrder], [2, 0, 1]);
  });

  test('reorderSection moves up', () {
    final items = apply(base, reorderSection(base, 2, 0));
    expect(todaySection(items), ['Eggs', 'Rice', 'Milk']);
  });

  test('reorderSection only returns items whose position changed', () {
    final first = apply(base, reorderSection(base, 2, 0)); // Eggs, Rice, Milk
    final section = groupToBuyByPlannedDate(first, kToday).first.items;
    final second = reorderSection(section, 1, 2); // Eggs, Milk, Rice
    expect(names(second)..sort(), ['Milk', 'Rice']);
  });

  test('out-of-range indexes are ignored or clamped', () {
    expect(reorderSection(base, 5, 0), isEmpty);
    final items = apply(base, reorderSection(base, 0, 99));
    expect(todaySection(items), ['Milk', 'Eggs', 'Rice']);
  });

  test('a new item lands at the bottom of a reordered section', () {
    final reordered = apply(base, reorderSection(base, 2, 0));
    final added = item('Bread', createdAt: DateTime(2026, 11, 23, 10));
    expect(todaySection([...reordered, added]), ['Eggs', 'Rice', 'Milk', 'Bread']);
  });

  test('editing to another day clears the manual position', () {
    final placed = base.first.copyWith(sortOrder: 0);
    final sameDay = applyEdit(placed,
        name: 'Rice', quantity: '', plannedDate: kToday);
    final moved = applyEdit(placed,
        name: 'Rice', quantity: '', plannedDate: DateTime(2026, 11, 25));
    expect(sameDay.sortOrder, 0);
    expect(moved.sortOrder, isNull);
  });

  test('sortOrder survives JSON and is optional for old records', () {
    final placed = base.first.copyWith(sortOrder: 3);
    expect(GroceryItem.fromJson(placed.toJson()).sortOrder, 3);

    final legacy = base.first.toJson()..remove('sortOrder');
    expect(GroceryItem.fromJson(legacy).sortOrder, isNull);
  });
}
