import 'date_range.dart';

/// Month-cycle date math. Fixed-day cycles are implemented here; the
/// income-anchored (payday) mode arrives with the Month cycle milestone.

DateTime _clampedDay(int year, int month, int day) {
  // DateTime(y, m + 1, 0) is the last day of month m (normalises across years).
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

/// The cycle containing [date] when cycles start on [startDay] (1–31).
/// A start day past the end of a short month falls on that month's last day,
/// and a date before this month's start day belongs to last month's cycle.
DateRange fixedDayCycle(DateTime date, int startDay) {
  if (startDay <= 1) {
    return DateRange(
      DateTime(date.year, date.month, 1),
      DateTime(date.year, date.month + 1, 1),
    );
  }
  var start = _clampedDay(date.year, date.month, startDay);
  if (date.isBefore(start)) {
    start = _clampedDay(date.year, date.month - 1, startDay);
  }
  final next = _clampedDay(start.year, start.month + 1, startDay);
  return DateRange(start, next);
}

/// The cycle immediately before [range] (the one containing the day before it starts).
DateRange previousFixedDayCycle(DateRange range, int startDay) {
  final dayBefore = DateTime(range.start.year, range.start.month, range.start.day - 1);
  return fixedDayCycle(dayBefore, startDay);
}
