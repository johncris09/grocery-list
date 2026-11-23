import '../models/grocery_item.dart';
import '../models/trip.dart';
import 'grocery_repository.dart';

/// Non-persistent store for tests and previews.
class InMemoryGroceryRepository implements GroceryRepository {
  InMemoryGroceryRepository({
    Iterable<GroceryItem> items = const [],
    Iterable<Trip> trips = const [],
  })  : items = {for (final i in items) i.id: i},
        trips = {for (final t in trips) t.id: t};

  final Map<String, GroceryItem> items;
  final Map<String, Trip> trips;

  @override
  Future<List<GroceryItem>> loadItems() async => items.values.toList();

  @override
  Future<List<Trip>> loadTrips() async => trips.values.toList();

  @override
  Future<void> upsertItems(Iterable<GroceryItem> items) async {
    for (final i in items) {
      this.items[i.id] = i;
    }
  }

  @override
  Future<void> deleteItem(String id) async => items.remove(id);

  @override
  Future<void> upsertTrip(Trip trip) async => trips[trip.id] = trip;
}
