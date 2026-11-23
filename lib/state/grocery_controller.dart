import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import '../data/models/grocery_item.dart';
import '../data/models/trip.dart';
import '../data/repositories/grocery_repository.dart';
import '../data/repositories/in_memory_grocery_repository.dart';
import '../domain/grocery_logic.dart' hide toggleBought;
import '../domain/grocery_logic.dart' as logic show toggleBought;

/// Everything loaded from storage at startup.
@immutable
class GroceryData {
  const GroceryData({this.items = const [], this.trips = const []});
  final List<GroceryItem> items;
  final List<Trip> trips;

  GroceryData copyWith({List<GroceryItem>? items, List<Trip>? trips}) =>
      GroceryData(items: items ?? this.items, trips: trips ?? this.trips);
}

/// Overridden in main.dart with the Hive repository (later: an API one).
final groceryRepositoryProvider = Provider<GroceryRepository>(
  (ref) => InMemoryGroceryRepository(),
);

/// Overridden in main.dart with what the repository loaded.
final initialGroceryDataProvider = Provider<GroceryData>(
  (ref) => const GroceryData(),
);

final clockProvider = Provider<Clock>((ref) => systemClock);

final idGeneratorProvider = Provider<IdGenerator>((ref) {
  const uuid = Uuid();
  return uuid.v4;
});

enum AddItemResult { added, emptyName, duplicate }

final groceryControllerProvider =
    NotifierProvider<GroceryController, GroceryData>(GroceryController.new);

/// Applies user actions: updates in-memory state immediately, then writes
/// through to the repository.
class GroceryController extends Notifier<GroceryData> {
  late GroceryRepository _repo;
  late Clock _clock;
  late IdGenerator _newId;

  @override
  GroceryData build() {
    // read, not watch: these services never change at runtime, and a
    // rebuild would throw away unsaved in-memory state.
    _repo = ref.read(groceryRepositoryProvider);
    _clock = ref.read(clockProvider);
    _newId = ref.read(idGeneratorProvider);
    return ref.watch(initialGroceryDataProvider);
  }

  DateTime get now => _clock();
  DateTime get today => dateOnly(_clock());

  /// Adds "Rice 5 kg" planned for [plannedDate]. A same-name item on the
  /// same date returns [AddItemResult.duplicate] unless [allowDuplicate].
  AddItemResult addItem(
    String raw,
    DateTime plannedDate, {
    bool allowDuplicate = false,
  }) {
    final entry = parseEntry(raw);
    if (entry == null) return AddItemResult.emptyName;
    if (!allowDuplicate &&
        hasDuplicateOnDate(state.items, entry.name, plannedDate, now)) {
      return AddItemResult.duplicate;
    }
    final created = newItem(
      id: _newId(),
      entry: entry,
      plannedDate: plannedDate,
      now: now,
    );
    state = state.copyWith(items: [...state.items, created]);
    _persist(_repo.upsertItems([created]));
    return AddItemResult.added;
  }

  void toggleBought(String id) {
    final current = state.items.firstWhere((i) => i.id == id);
    final updated = logic.toggleBought(current, now);
    _replaceItems([updated]);
    _persist(_repo.upsertItems([updated]));
  }

  void deleteItem(String id) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
    _persist(_repo.deleteItem(id));
  }

  /// Archives today's bought items. Returns the trip, or null if there
  /// was nothing bought today.
  Trip? saveTrip() {
    final result = saveTodayAsTrip(state.items, now, _newId);
    if (result == null) return null;
    _replaceItems(result.archivedItems);
    state = state.copyWith(trips: [...state.trips, result.trip]);
    _persist(Future.wait([
      _repo.upsertItems(result.archivedItems),
      _repo.upsertTrip(result.trip),
    ]));
    return result.trip;
  }

  /// Copies a trip's items into today's To buy list. Returns how many
  /// were added (names already on today's list are skipped).
  int buyAgain(String tripId) {
    final trip = state.trips.firstWhere((t) => t.id == tripId);
    final copies = copyTripToToday(trip, state.items, now, _newId);
    if (copies.isEmpty) return 0;
    state = state.copyWith(items: [...state.items, ...copies]);
    _persist(_repo.upsertItems(copies));
    return copies.length;
  }

  void _replaceItems(List<GroceryItem> updated) {
    final byId = {for (final i in updated) i.id: i};
    state = state.copyWith(
      items: [for (final i in state.items) byId[i.id] ?? i],
    );
  }

  void _persist(Future<void> write) {
    unawaited(write.catchError((Object e, StackTrace s) {
      debugPrint('GroceryController: failed to persist: $e');
    }));
  }
}
