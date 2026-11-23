import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/grocery_item.dart';
import '../models/trip.dart';
import 'grocery_repository.dart';

/// Local, offline store. Records are kept as JSON maps (no type adapters),
/// so the stored shape matches what a future API would send.
class HiveGroceryRepository implements GroceryRepository {
  HiveGroceryRepository._(this._items, this._trips);

  static const itemsBox = 'items';
  static const tripsBox = 'trips';

  final Box<Map> _items;
  final Box<Map> _trips;

  static Future<HiveGroceryRepository> open() async {
    await Hive.initFlutter();
    final items = await Hive.openBox<Map>(itemsBox);
    final trips = await Hive.openBox<Map>(tripsBox);
    return HiveGroceryRepository._(items, trips);
  }

  @override
  Future<List<GroceryItem>> loadItems() async =>
      _items.values.map(GroceryItem.fromJson).toList();

  @override
  Future<List<Trip>> loadTrips() async =>
      _trips.values.map(Trip.fromJson).toList();

  @override
  Future<void> upsertItems(Iterable<GroceryItem> items) =>
      _items.putAll({for (final i in items) i.id: i.toJson()});

  @override
  Future<void> deleteItem(String id) => _items.delete(id);

  @override
  Future<void> upsertTrip(Trip trip) => _trips.put(trip.id, trip.toJson());
}
