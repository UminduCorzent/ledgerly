import 'package:intl/intl.dart';

import '../../domain/date_range.dart';
import '../strings/app_strings.dart';

final DateFormat _dayMonth = DateFormat('d MMM', 'en_US');
final DateFormat _weekdayDayMonth = DateFormat('EEE d MMM', 'en_US');
final DateFormat _full = DateFormat('EEE d MMM yyyy', 'en_US');
final DateFormat _time = DateFormat('HH:mm', 'en_US');
final DateFormat _monthYear = DateFormat('MMMM yyyy', 'en_US');

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Yesterday", "Mon 3 Oct" (adds the year when it isn't this year).
String dayLabel(DateTime d, AppStrings s, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (_sameDay(d, n)) return s.today;
  if (_sameDay(d, DateTime(n.year, n.month, n.day - 1))) return s.yesterday;
  return d.year == n.year ? _weekdayDayMonth.format(d) : _full.format(d);
}

String timeLabel(DateTime d) => _time.format(d);

String fullDateTime(DateTime d) => '${_full.format(d)} · ${_time.format(d)}';

String monthYear(DateTime d) => _monthYear.format(d);

/// "1 – 31 Oct", "25 Sep – 24 Oct", or "25 Sep – ongoing".
String rangeLabel(DateRange r, {String ongoing = 'ongoing'}) {
  final last = r.lastDay;
  if (last == null) return '${_dayMonth.format(r.start)} – $ongoing';
  if (r.start.month == last.month && r.start.year == last.year) {
    return '${r.start.day} – ${_dayMonth.format(last)}';
  }
  return '${_dayMonth.format(r.start)} – ${_dayMonth.format(last)}';
}
