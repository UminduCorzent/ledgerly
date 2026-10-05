import '../models/txn.dart';
import 'date_range.dart';

/// Totals for one account's rows. Only counted rows contribute — rows marked
/// "Exclude from totals" never move any figure.
class PeriodTotals {
  const PeriodTotals({
    this.income = 0,
    this.expense = 0,
    this.transferIn = 0,
    this.transferOut = 0,
  });

  final double income;
  final double expense;
  final double transferIn;
  final double transferOut;

  /// The app's single fixed balance rule:
  /// income − expense + transfers in − transfers out.
  double get net => income - expense + transferIn - transferOut;
}

PeriodTotals totalsOf(Iterable<Txn> txns, [DateRange? range]) {
  var income = 0.0, expense = 0.0, tIn = 0.0, tOut = 0.0;
  for (final t in txns) {
    if (!t.isCounted) continue;
    if (range != null && !range.contains(t.date)) continue;
    switch (t.type) {
      case TxnType.income:
        income += t.amount;
      case TxnType.expense:
        expense += t.amount;
      case TxnType.transfer:
        if (t.direction == TransferDirection.outgoing) {
          tOut += t.amount;
        } else {
          tIn += t.amount;
        }
    }
  }
  return PeriodTotals(
    income: income,
    expense: expense,
    transferIn: tIn,
    transferOut: tOut,
  );
}

/// One slice of a breakdown. A null [categoryId] is the combined "Other" slice.
class BreakdownEntry {
  const BreakdownEntry(this.categoryId, this.amount);

  final String? categoryId;
  final double amount;

  bool get isOther => categoryId == null;
}

class Breakdown {
  const Breakdown(this.total, this.entries);

  static const empty = Breakdown(0, []);

  final double total;

  /// Largest first; at most [top] categories plus one "Other" entry.
  final List<BreakdownEntry> entries;

  double get largest => entries.isEmpty ? 0 : entries.first.amount;
}

/// Spending or income grouped by category: the top [top] categories plus "Other".
/// Percentages shown to the user are always of the full [Breakdown.total].
Breakdown breakdownOf(
  Iterable<Txn> txns,
  TxnType type, {
  DateRange? range,
  int top = 5,
}) {
  assert(type != TxnType.transfer);
  final byCat = <String, double>{};
  var uncategorised = 0.0;
  for (final t in txns) {
    if (t.type != type || !t.isCounted) continue;
    if (range != null && !range.contains(t.date)) continue;
    final id = t.categoryId;
    if (id == null) {
      uncategorised += t.amount;
    } else {
      byCat[id] = (byCat[id] ?? 0) + t.amount;
    }
  }
  final sorted = byCat.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  final total = sorted.fold<double>(uncategorised, (s, e) => s + e.value);
  if (total <= 0) return Breakdown.empty;

  final entries = <BreakdownEntry>[
    for (final e in sorted.take(top)) BreakdownEntry(e.key, e.value),
  ];
  final rest = sorted.skip(top).fold<double>(uncategorised, (s, e) => s + e.value);
  if (rest > 0.005) entries.add(BreakdownEntry(null, rest));
  return Breakdown(total, entries);
}
