import '../models/txn.dart';
import 'date_range.dart';

/// "Counting" filter: all rows, only rows that count toward totals, or only excluded ones.
enum CountingFilter { all, counted, excluded }

enum TxnSort {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
  categoryAsc,
  categoryDesc,
  typeAsc,
  typeDesc,
  accountAsc,
  accountDesc;

  /// Only date sorts group the list by day.
  bool get isChronological => this == dateDesc || this == dateAsc;

  static TxnSort parse(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => TxnSort.dateDesc);
}

/// Filters other than the date range (the month navigator owns the range).
/// Groups combine with AND; values inside a group with OR.
class TxnFilter {
  const TxnFilter({
    this.types = const {},
    this.categoryNames = const {},
    this.accountIds = const {},
    this.minAmount,
    this.maxAmount,
    this.counting = CountingFilter.all,
  });

  static const TxnFilter none = TxnFilter();

  final Set<TxnType> types;

  /// Lower-case names, so a filter works across several selected accounts
  /// (each account has its own category records).
  final Set<String> categoryNames;

  /// Empty means "the active account only".
  final Set<String> accountIds;
  final double? minAmount;
  final double? maxAmount;
  final CountingFilter counting;

  bool get isEmpty => activeCount == 0;

  int get activeCount => [
        types.isNotEmpty,
        categoryNames.isNotEmpty,
        accountIds.isNotEmpty,
        minAmount != null || maxAmount != null,
        counting != CountingFilter.all,
      ].where((b) => b).length;

  static const Object _unset = Object();

  TxnFilter copyWith({
    Set<TxnType>? types,
    Set<String>? categoryNames,
    Set<String>? accountIds,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    CountingFilter? counting,
  }) =>
      TxnFilter(
        types: types ?? this.types,
        categoryNames: categoryNames ?? this.categoryNames,
        accountIds: accountIds ?? this.accountIds,
        minAmount: identical(minAmount, _unset) ? this.minAmount : minAmount as double?,
        maxAmount: identical(maxAmount, _unset) ? this.maxAmount : maxAmount as double?,
        counting: counting ?? this.counting,
      );
}

/// True when [t] passes [range], [f] and the free-text [query].
/// Search looks at description, category name and notes, ignoring case.
bool txnMatches(
  Txn t,
  TxnFilter f, {
  DateRange? range,
  String query = '',
  required String Function(Txn) categoryName,
}) {
  if (range != null && !range.contains(t.date)) return false;
  if (f.types.isNotEmpty && !f.types.contains(t.type)) return false;
  if (f.categoryNames.isNotEmpty &&
      (t.isTransfer || !f.categoryNames.contains(categoryName(t).toLowerCase()))) {
    return false;
  }
  final min = f.minAmount, max = f.maxAmount;
  if (min != null && t.amount < min) return false;
  if (max != null && t.amount > max) return false;
  switch (f.counting) {
    case CountingFilter.all:
      break;
    case CountingFilter.counted:
      if (!t.isCounted) return false;
    case CountingFilter.excluded:
      if (t.isCounted) return false;
  }
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty) {
    final hay = '${t.description}\n${categoryName(t)}\n${t.notes ?? ''}'.toLowerCase();
    if (!hay.contains(q)) return false;
  }
  return true;
}

int _newestFirst(Txn a, Txn b) {
  final c = b.date.compareTo(a.date);
  return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
}

int _typeRank(TxnType t) => switch (t) {
      TxnType.income => 0,
      TxnType.expense => 1,
      TxnType.transfer => 2,
    };

/// Comparator for [sort]; ties always fall back to newest first so order is stable.
Comparator<Txn> txnComparator(
  TxnSort sort, {
  required String Function(Txn) categoryName,
  required String Function(Txn) accountName,
}) {
  int tie(int c, Txn a, Txn b) => c != 0 ? c : _newestFirst(a, b);
  int byName(String Function(Txn) f, Txn a, Txn b) =>
      f(a).toLowerCase().compareTo(f(b).toLowerCase());
  return switch (sort) {
    TxnSort.dateDesc => _newestFirst,
    TxnSort.dateAsc => (a, b) => _newestFirst(b, a),
    TxnSort.amountDesc => (a, b) => tie(b.amount.compareTo(a.amount), a, b),
    TxnSort.amountAsc => (a, b) => tie(a.amount.compareTo(b.amount), a, b),
    TxnSort.categoryAsc => (a, b) => tie(byName(categoryName, a, b), a, b),
    TxnSort.categoryDesc => (a, b) => tie(byName(categoryName, b, a), a, b),
    TxnSort.typeAsc => (a, b) => tie(_typeRank(a.type) - _typeRank(b.type), a, b),
    TxnSort.typeDesc => (a, b) => tie(_typeRank(b.type) - _typeRank(a.type), a, b),
    TxnSort.accountAsc => (a, b) => tie(byName(accountName, a, b), a, b),
    TxnSort.accountDesc => (a, b) => tie(byName(accountName, b, a), a, b),
  };
}

/// Quick date ranges offered in the Filter sheet.
enum DatePreset { today, thisWeek, thisMonth, lastMonth, last3Months, thisYear, allTime }

/// The range for [preset]. "Month" presets follow the account's month cycle via
/// [cycleOf] (the cycle containing a date). Returns null for all time.
DateRange? presetRange(
  DatePreset preset,
  DateTime now,
  DateRange Function(DateTime) cycleOf,
) {
  final today = DateTime(now.year, now.month, now.day);
  DateRange previous(DateRange r) =>
      cycleOf(DateTime(r.start.year, r.start.month, r.start.day - 1));
  switch (preset) {
    case DatePreset.today:
      return DateRange(today, DateTime(today.year, today.month, today.day + 1));
    case DatePreset.thisWeek:
      final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
      return DateRange(monday, DateTime(monday.year, monday.month, monday.day + 7));
    case DatePreset.thisMonth:
      return cycleOf(now);
    case DatePreset.lastMonth:
      return previous(cycleOf(now));
    case DatePreset.last3Months:
      final current = cycleOf(now);
      final first = previous(previous(current));
      return DateRange(first.start, current.end);
    case DatePreset.thisYear:
      return DateRange(DateTime(now.year), DateTime(now.year + 1));
    case DatePreset.allTime:
      return null;
  }
}
