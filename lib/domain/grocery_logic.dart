import '../core/dates.dart';
import '../data/models/grocery_item.dart';
import '../data/models/trip.dart';

/// Pure business rules. No Flutter, no storage, no clock reads: "now" and
/// id generation are always passed in, which keeps these easy to test.

typedef IdGenerator = String Function();

/// A section on screen: all items that share one calendar date.
class DateGroup {
  const DateGroup({
    required this.date,
    required this.isToday,
    required this.items,
  });
  final DateTime date;
  final bool isToday;
  final List<GroceryItem> items;
}

/// Name + quantity typed into the single "Add an item" field.
class ParsedEntry {
  const ParsedEntry(this.name, this.quantity);
  final String name;
  final String quantity;
}

final _trailingQuantity = RegExp(
  r'^(.*\S)\s+(\d+(?:[.,]\d+)?\s*[A-Za-z]*\.?|x\s?\d+)$',
);

/// "Rice 5 kg" -> (Rice, 5 kg); "Bananas 1 bunch" -> (Bananas, 1 bunch);
/// "Milk" -> (Milk, ""). Returns null for an empty or blank entry.
ParsedEntry? parseEntry(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return null;
  final m = _trailingQuantity.firstMatch(text);
  if (m == null) return ParsedEntry(text, '');
  return ParsedEntry(m.group(1)!.trim(), m.group(2)!.trim());
}

String normalizeName(String name) => name.trim().toLowerCase();

/// Overdue unbought items roll forward into today.
DateTime effectivePlannedDate(GroceryItem item, DateTime today) {
  final t = dateOnly(today);
  return item.plannedDate.isBefore(t) ? t : item.plannedDate;
}

List<GroceryItem> toBuyItems(Iterable<GroceryItem> items) =>
    items.where((i) => i.status == ItemStatus.toBuy).toList();

/// Bought but not yet archived into a trip (what the "Bought" tab shows).
List<GroceryItem> boughtItems(Iterable<GroceryItem> items) =>
    items.where((i) => i.isBought && !i.isArchived).toList();

/// "To buy" sections: Today first, then each future date ascending.
List<DateGroup> groupToBuyByPlannedDate(
  Iterable<GroceryItem> items,
  DateTime today,
) {
  final t = dateOnly(today);
  final byDate = <DateTime, List<GroceryItem>>{};
  for (final item in toBuyItems(items)) {
    byDate.putIfAbsent(effectivePlannedDate(item, t), () => []).add(item);
  }
  final dates = byDate.keys.toList()..sort();
  return [
    for (final d in dates)
      DateGroup(
        date: d,
        isToday: isSameDay(d, t),
        items: byDate[d]!..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      ),
  ];
}

/// "Bought" sections: grouped by the day each item was bought, newest first.
List<DateGroup> groupBoughtByDate(
  Iterable<GroceryItem> items,
  DateTime today,
) {
  final byDate = <DateTime, List<GroceryItem>>{};
  for (final item in boughtItems(items)) {
    byDate.putIfAbsent(dateOnly(item.boughtAt!), () => []).add(item);
  }
  final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in dates)
      DateGroup(
        date: d,
        isToday: isSameDay(d, today),
        items: byDate[d]!..sort((a, b) => b.boughtAt!.compareTo(a.boughtAt!)),
      ),
  ];
}

int countToBuyToday(Iterable<GroceryItem> items, DateTime today) =>
    toBuyItems(items)
        .where((i) => isSameDay(effectivePlannedDate(i, today), today))
        .length;

int countPlanned(Iterable<GroceryItem> items, DateTime today) =>
    toBuyItems(items).where((i) => i.plannedDate.isAfter(dateOnly(today))).length;

/// Tick: moves the item to Bought and stamps the time.
GroceryItem markBought(GroceryItem item, DateTime now) =>
    item.copyWith(status: ItemStatus.bought, boughtAt: now);

/// Untick: back to To buy. Archived items cannot be unticked.
GroceryItem markToBuy(GroceryItem item) => item.isArchived
    ? item
    : item.copyWith(status: ItemStatus.toBuy, clearBoughtAt: true);

GroceryItem toggleBought(GroceryItem item, DateTime now) =>
    item.isBought ? markToBuy(item) : markBought(item, now);

/// True when a to-buy item with the same name is already planned for
/// [date] (case-insensitive, overdue items count as today). [excludeId]
/// skips the item being edited so it doesn't clash with itself.
bool hasDuplicateOnDate(
  Iterable<GroceryItem> items,
  String name,
  DateTime date,
  DateTime today, {
  String? excludeId,
}) {
  final key = normalizeName(name);
  final d = dateOnly(date);
  return toBuyItems(items).any(
    (i) =>
        i.id != excludeId &&
        normalizeName(i.name) == key &&
        isSameDay(effectivePlannedDate(i, today), d),
  );
}

/// Collapses inner whitespace and trims: "  Brown   rice " -> "Brown rice".
String cleanText(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Applies an edit from the edit sheet. Name must already be validated.
GroceryItem applyEdit(
  GroceryItem item, {
  required String name,
  required String quantity,
  required DateTime plannedDate,
}) =>
    item.copyWith(
      name: cleanText(name),
      quantity: cleanText(quantity),
      plannedDate: dateOnly(plannedDate),
    );

GroceryItem newItem({
  required String id,
  required ParsedEntry entry,
  required DateTime plannedDate,
  required DateTime now,
}) =>
    GroceryItem(
      id: id,
      name: entry.name,
      quantity: entry.quantity,
      plannedDate: dateOnly(plannedDate),
      status: ItemStatus.toBuy,
      createdAt: now,
    );

class TripResult {
  const TripResult(this.trip, this.archivedItems);
  final Trip trip;
  final List<GroceryItem> archivedItems;
}

/// Archives everything bought today into one trip. Returns null if
/// nothing was bought today.
TripResult? saveTodayAsTrip(
  Iterable<GroceryItem> items,
  DateTime now,
  IdGenerator newId,
) {
  final today = dateOnly(now);
  final boughtToday = boughtItems(items)
      .where((i) => isSameDay(i.boughtAt!, today))
      .toList()
    ..sort((a, b) => a.boughtAt!.compareTo(b.boughtAt!));
  if (boughtToday.isEmpty) return null;
  final trip = Trip(
    id: newId(),
    date: today,
    itemIds: [for (final i in boughtToday) i.id],
    createdAt: now,
  );
  return TripResult(
    trip,
    [for (final i in boughtToday) i.copyWith(tripId: trip.id)],
  );
}

/// The items archived in [trip], in the order they were bought.
List<GroceryItem> itemsOfTrip(Trip trip, Iterable<GroceryItem> items) {
  final byId = {for (final i in items) i.id: i};
  return [
    for (final id in trip.itemIds)
      if (byId[id] != null) byId[id]!,
  ];
}

/// Fresh to-buy copies of a trip's items, planned for today. Names that
/// are already on today's to-buy list are skipped.
List<GroceryItem> copyTripToToday(
  Trip trip,
  Iterable<GroceryItem> items,
  DateTime now,
  IdGenerator newId,
) {
  final today = dateOnly(now);
  final taken = {
    for (final i in toBuyItems(items))
      if (isSameDay(effectivePlannedDate(i, today), today)) normalizeName(i.name),
  };
  final copies = <GroceryItem>[];
  var tick = 0;
  for (final source in itemsOfTrip(trip, items)) {
    final key = normalizeName(source.name);
    if (!taken.add(key)) continue;
    copies.add(GroceryItem(
      id: newId(),
      name: source.name,
      quantity: source.quantity,
      plannedDate: today,
      status: ItemStatus.toBuy,
      // Keep the trip's order stable in the createdAt-sorted list.
      createdAt: now.add(Duration(microseconds: tick++)),
    ));
  }
  return copies;
}

/// A trip as shown on the history screen, after search filtering.
class TripView {
  const TripView(this.trip, this.items, this.totalCount);
  final Trip trip;
  final List<GroceryItem> items;
  final int totalCount;
}

/// Trips from the last [days] days, newest first, filtered by [query]
/// (case-insensitive substring of item names). Trips with no matching
/// item are dropped while searching.
List<TripView> historyTrips(
  Iterable<Trip> trips,
  Iterable<GroceryItem> items,
  DateTime today, {
  String query = '',
  int days = 30,
}) {
  final cutoff = dateOnly(today).subtract(Duration(days: days - 1));
  final q = normalizeName(query);
  final sorted = trips.where((t) => !t.date.isBefore(cutoff)).toList()
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
  final views = <TripView>[];
  for (final trip in sorted) {
    final all = itemsOfTrip(trip, items);
    final shown = q.isEmpty
        ? all
        : all.where((i) => normalizeName(i.name).contains(q)).toList();
    if (shown.isEmpty) continue;
    views.add(TripView(trip, shown, all.length));
  }
  return views;
}
