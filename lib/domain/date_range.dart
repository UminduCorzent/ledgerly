/// A half-open date range: [start] inclusive, [end] exclusive.
/// A null [end] means the range is open (e.g. a payday cycle still running).
class DateRange {
  const DateRange(this.start, [this.end]);

  final DateTime start;
  final DateTime? end;

  bool contains(DateTime d) =>
      !d.isBefore(start) && (end == null || d.isBefore(end!));

  bool get isOpen => end == null;

  /// Last day shown to the user (end − 1 day), or null when open.
  DateTime? get lastDay =>
      end == null ? null : DateTime(end!.year, end!.month, end!.day - 1);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start, $end)';
}
