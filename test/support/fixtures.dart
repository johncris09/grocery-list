import 'package:grocery_list/data/models/grocery_item.dart';

/// Mon, Nov 23 2026, 14:00 local — matches the design mock.
final kNow = DateTime(2026, 11, 23, 14);
final kToday = DateTime(2026, 11, 23);

/// Sequential ids: id-1, id-2, ...
String Function() sequentialIds([String prefix = 'id']) {
  var n = 0;
  return () => '$prefix-${++n}';
}

GroceryItem item(
  String name, {
  String? id,
  String quantity = '',
  DateTime? planned,
  DateTime? boughtAt,
  String? tripId,
  DateTime? createdAt,
}) {
  return GroceryItem(
    id: id ?? name.toLowerCase().replaceAll(' ', '-'),
    name: name,
    quantity: quantity,
    plannedDate: planned ?? kToday,
    status: boughtAt == null ? ItemStatus.toBuy : ItemStatus.bought,
    boughtAt: boughtAt,
    tripId: tripId,
    createdAt: createdAt ?? DateTime(2026, 11, 20),
  );
}
