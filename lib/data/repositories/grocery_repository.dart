import '../models/grocery_item.dart';
import '../models/trip.dart';

/// Everything the app persists. The UI and state layer only talk to this
/// interface, so a Laravel API implementation (e.g. `ApiGroceryRepository`
/// using GET/PUT/DELETE /items and POST /trips) can replace
/// [HiveGroceryRepository] by changing one provider override in main.dart.
abstract class GroceryRepository {
  Future<List<GroceryItem>> loadItems();
  Future<List<Trip>> loadTrips();

  /// Insert or update by id.
  Future<void> upsertItems(Iterable<GroceryItem> items);
  Future<void> deleteItem(String id);

  /// Insert or update by id.
  Future<void> upsertTrip(Trip trip);
}
