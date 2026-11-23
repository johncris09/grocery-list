import '../../core/dates.dart';

enum ItemStatus { toBuy, bought }

/// One line on the grocery list.
class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.plannedDate,
    required this.status,
    required this.createdAt,
    this.boughtAt,
    this.tripId,
    this.sortOrder,
  });

  final String id;
  final String name;

  /// Free text, e.g. "5 kg" or "1 bunch". May be empty.
  final String quantity;

  /// Calendar date (time stripped) the user plans to buy this on.
  final DateTime plannedDate;
  final ItemStatus status;

  /// When it was ticked off; null while still to buy.
  final DateTime? boughtAt;

  /// Set once the item is archived into a saved trip.
  final String? tripId;
  final DateTime createdAt;

  /// Manual position within its To buy section, set when the user drags
  /// rows. Null means "not reordered yet": the item sorts by [createdAt].
  final int? sortOrder;

  bool get isBought => status == ItemStatus.bought;
  bool get isArchived => tripId != null;

  GroceryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    DateTime? plannedDate,
    ItemStatus? status,
    DateTime? boughtAt,
    bool clearBoughtAt = false,
    String? tripId,
    bool clearTripId = false,
    DateTime? createdAt,
    int? sortOrder,
    bool clearSortOrder = false,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      plannedDate: plannedDate ?? this.plannedDate,
      status: status ?? this.status,
      boughtAt: clearBoughtAt ? null : (boughtAt ?? this.boughtAt),
      tripId: clearTripId ? null : (tripId ?? this.tripId),
      createdAt: createdAt ?? this.createdAt,
      sortOrder: clearSortOrder ? null : (sortOrder ?? this.sortOrder),
    );
  }

  /// camelCase JSON; a Laravel API resource can emit the same shape later.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'plannedDate': dateKey(plannedDate),
        'status': status.name,
        'boughtAt': boughtAt?.toIso8601String(),
        'tripId': tripId,
        'createdAt': createdAt.toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory GroceryItem.fromJson(Map<dynamic, dynamic> json) => GroceryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as String?) ?? '',
        plannedDate: parseDateKey(json['plannedDate'] as String),
        status: ItemStatus.values.byName(json['status'] as String),
        boughtAt: json['boughtAt'] == null
            ? null
            : DateTime.parse(json['boughtAt'] as String),
        tripId: json['tripId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        sortOrder: json['sortOrder'] as int?,
      );

  @override
  String toString() => 'GroceryItem($name, $quantity, ${status.name})';
}
