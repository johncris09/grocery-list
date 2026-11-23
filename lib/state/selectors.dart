import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../domain/grocery_logic.dart';
import 'grocery_controller.dart';

/// Derived, read-only views of the grocery state for the UI.

DateTime _today(Ref ref) => dateOnly(ref.watch(clockProvider)());

final toBuyGroupsProvider = Provider<List<DateGroup>>((ref) {
  final data = ref.watch(groceryControllerProvider);
  return groupToBuyByPlannedDate(data.items, _today(ref));
});

final boughtGroupsProvider = Provider<List<DateGroup>>((ref) {
  final data = ref.watch(groceryControllerProvider);
  return groupBoughtByDate(data.items, _today(ref));
});

class ListCounts {
  const ListCounts({
    required this.toBuy,
    required this.bought,
    required this.today,
    required this.planned,
  });
  final int toBuy;
  final int bought;
  final int today;
  final int planned;
}

final countsProvider = Provider<ListCounts>((ref) {
  final items = ref.watch(groceryControllerProvider).items;
  final today = _today(ref);
  return ListCounts(
    toBuy: toBuyItems(items).length,
    bought: boughtItems(items).length,
    today: countToBuyToday(items, today),
    planned: countPlanned(items, today),
  );
});

final historySearchProvider = StateProvider<String>((ref) => '');

final historyProvider = Provider<List<TripView>>((ref) {
  final data = ref.watch(groceryControllerProvider);
  return historyTrips(
    data.trips,
    data.items,
    _today(ref),
    query: ref.watch(historySearchProvider),
  );
});
