import '../../core/dates.dart';

/// A completed shopping trip: a snapshot of items bought on one day.
class Trip {
  const Trip({
    required this.id,
    required this.date,
    required this.itemIds,
    required this.createdAt,
  });

  final String id;

  /// Calendar date of the trip (time stripped).
  final DateTime date;
  final List<String> itemIds;

  /// Exact save time; orders several trips saved on the same day.
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateKey(date),
        'itemIds': itemIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<dynamic, dynamic> json) => Trip(
        id: json['id'] as String,
        date: parseDateKey(json['date'] as String),
        itemIds: (json['itemIds'] as List).cast<String>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
