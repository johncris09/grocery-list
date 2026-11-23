import 'package:intl/intl.dart';

/// Date helpers. Everything uses the device's local timezone
/// (Asia/Manila on the target phone); no UTC conversion is applied.

/// A function that returns "now". Injected so tests can freeze time.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();

/// Strips the time part: 2026-11-23 14:05 -> 2026-11-23 00:00 (local).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Storage key for a calendar date, e.g. "2026-11-23".
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// "Mon, Nov 23"
String formatShortDate(DateTime d) => DateFormat('EEE, MMM d').format(d);

/// History section label: "Today, Mon Nov 23" or "Sun, Nov 22".
String formatHistoryDate(DateTime d, DateTime today) => isSameDay(d, today)
    ? 'Today, ${DateFormat('EEE MMM d').format(d)}'
    : formatShortDate(d);
