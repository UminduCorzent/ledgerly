import 'date_range.dart';

// Month-cycle date math: what "this month" means for an account.
//
// * Fixed day: cycles restart on a chosen day (1–31) each month.
// * Payday (income-anchored): cycles start on the account's own qualifying
//   income ("anchors"). The latest cycle stays open until the next payday is
//   recorded, rather than snapping to a predicted date.

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clampedDay(int year, int month, int day) {
  // DateTime(y, m + 1, 0) is the last day of month m (normalises across years).
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

/// Whole calendar days from [a] to [b] (DST-safe).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

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

/// Collapses qualifying income dates into cycle starts. The first date is
/// always an anchor; a later date becomes a new anchor only once at least
/// [cooldownDays] have passed since the previous anchor, so a bonus or refund
/// shortly after the salary doesn't start a second cycle. Order-independent;
/// compares calendar dates only. Returns ascending dates.
List<DateTime> anchorsFrom(Iterable<DateTime> qualifyingDates, int cooldownDays) {
  final sorted = qualifyingDates.map(_dateOnly).toList()..sort();
  if (sorted.isEmpty) return const [];
  final anchors = <DateTime>[sorted.first];
  for (final d in sorted.skip(1)) {
    final last = anchors.last;
    final cooldownEnd = DateTime(last.year, last.month, last.day + cooldownDays);
    if (!d.isBefore(cooldownEnd)) anchors.add(d);
  }
  return anchors;
}

/// The cycle containing [date] in payday mode. [anchors] must be ascending.
/// * No anchors → the fixed-day cycle for [fallbackStartDay].
/// * Before the first anchor → that fixed-day cycle, cut off at the first anchor.
/// * Otherwise → from the latest anchor on/before [date] to the next anchor, or
///   **open** (null end) when no later payday exists yet.
DateRange anchoredCycle(DateTime date, List<DateTime> anchors, {required int fallbackStartDay}) {
  final d = _dateOnly(date);
  if (anchors.isEmpty) return fixedDayCycle(d, fallbackStartDay);
  final first = anchors.first;
  if (d.isBefore(first)) {
    final fallback = fixedDayCycle(d, fallbackStartDay);
    final end = fallback.end;
    return (end != null && end.isAfter(first)) ? DateRange(fallback.start, first) : fallback;
  }
  var start = first;
  DateTime? next;
  for (final a in anchors) {
    if (!a.isAfter(d)) {
      start = a;
    } else {
      next = a;
      break;
    }
  }
  return DateRange(start, next);
}

/// Median gap in days between consecutive anchors (30 with fewer than two).
/// Used to tell when an open cycle is "running long".
int typicalCycleLength(List<DateTime> anchors) {
  if (anchors.length < 2) return 30;
  final gaps = <int>[
    for (var i = 1; i < anchors.length; i++) daysBetween(anchors[i - 1], anchors[i]),
  ]..sort();
  final mid = gaps.length ~/ 2;
  return gaps.length.isOdd ? gaps[mid] : ((gaps[mid - 1] + gaps[mid]) / 2).round();
}

enum CycleMode {
  fixedDay,
  payday;

  static CycleMode parse(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => CycleMode.fixedDay);
}

/// Per-account month-cycle settings.
class CycleConfig {
  const CycleConfig({
    this.mode = CycleMode.fixedDay,
    this.startDay = 1,
    this.anchorCategoryIds = const {},
    this.minAmount = 0,
    this.cooldownDays = 20,
    this.pinnedStart,
  });

  static const CycleConfig calendar = CycleConfig();

  final CycleMode mode;

  /// Fixed-day start (also the fallback before the first payday). 1 = calendar month.
  final int startDay;

  /// Income categories that count as payday. Empty = any income.
  final Set<String> anchorCategoryIds;
  final double minAmount;

  /// 1–60 days; income inside this window after a payday doesn't start a new cycle.
  final int cooldownDays;

  /// A manually pinned cycle start, treated as one more qualifying date.
  final DateTime? pinnedStart;

  bool get isCalendar => mode == CycleMode.fixedDay && startDay <= 1;

  static const Object _unset = Object();

  CycleConfig copyWith({
    CycleMode? mode,
    int? startDay,
    Set<String>? anchorCategoryIds,
    double? minAmount,
    int? cooldownDays,
    Object? pinnedStart = _unset,
  }) =>
      CycleConfig(
        mode: mode ?? this.mode,
        startDay: (startDay ?? this.startDay).clamp(1, 31),
        anchorCategoryIds: anchorCategoryIds ?? this.anchorCategoryIds,
        minAmount: minAmount ?? this.minAmount,
        cooldownDays: (cooldownDays ?? this.cooldownDays).clamp(1, 60),
        pinnedStart: identical(pinnedStart, _unset) ? this.pinnedStart : pinnedStart as DateTime?,
      );

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'startDay': startDay,
        'anchorCategoryIds': anchorCategoryIds.toList(),
        'minAmount': minAmount,
        'cooldownDays': cooldownDays,
        'pinnedStart': pinnedStart?.millisecondsSinceEpoch,
      };

  factory CycleConfig.fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return calendar;
    final pinned = m['pinnedStart'];
    return CycleConfig(
      mode: CycleMode.parse(m['mode'] as String?),
      startDay: ((m['startDay'] as num?)?.toInt() ?? 1).clamp(1, 31),
      anchorCategoryIds: {
        for (final v in (m['anchorCategoryIds'] as List?) ?? const []) v as String,
      },
      minAmount: ((m['minAmount'] as num?) ?? 0).toDouble(),
      cooldownDays: ((m['cooldownDays'] as num?)?.toInt() ?? 20).clamp(1, 60),
      pinnedStart: pinned == null ? null : DateTime.fromMillisecondsSinceEpoch((pinned as num).toInt()),
    );
  }
}
