import '../models/txn.dart';
import 'date_range.dart';

/// Totals for one account's rows. Only counted rows contribute — rows marked
/// "Exclude from totals" never move any figure.
///
/// Transfers count: an incoming leg is part of [income] and an outgoing leg is
/// part of [expense] (so converting a USD salary into another account shows as
/// money out of one and money into the other). [transferIn] and [transferOut]
/// are the transfer share of those figures.
class PeriodTotals {
  const PeriodTotals({
    this.income = 0,
    this.expense = 0,
    this.transferIn = 0,
    this.transferOut = 0,
  });

  /// Income rows plus incoming transfers.
  final double income;

  /// Expense rows plus outgoing transfers.
  final double expense;
  final double transferIn;
  final double transferOut;

  /// The app's single fixed balance rule: income − expense (transfers included).
  double get net => income - expense;
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
    income: income + tIn,
    expense: expense + tOut,
    transferIn: tIn,
    transferOut: tOut,
  );
}

/// One slice of a breakdown: a category, the combined "Other" slice (null
/// [categoryId]) or the "Transfers" slice ([isTransfers]).
class BreakdownEntry {
  const BreakdownEntry(this.categoryId, this.amount) : isTransfers = false;

  /// Transfers in (income breakdown) or out (spending breakdown).
  const BreakdownEntry.transfers(this.amount)
      : categoryId = null,
        isTransfers = true;

  final String? categoryId;
  final double amount;
  final bool isTransfers;

  bool get isOther => categoryId == null && !isTransfers;
}

class Breakdown {
  const Breakdown(this.total, this.entries);

  static const empty = Breakdown(0, []);

  final double total;

  /// Largest first (Other last); at most [top] categories, one "Transfers" and
  /// one "Other" entry.
  final List<BreakdownEntry> entries;

  double get largest => entries.isEmpty ? 0 : entries.first.amount;
}

/// Spending or income grouped by category: the top [top] categories plus "Other",
/// plus one "Transfers" slice for transfers in (income) or out (spending) so the
/// total matches [PeriodTotals]. The Transfers slice never takes a top-[top] place
/// and is never folded into "Other".
/// Percentages shown to the user are always of the full [Breakdown.total].
Breakdown breakdownOf(
  Iterable<Txn> txns,
  TxnType type, {
  DateRange? range,
  int top = 5,
}) {
  assert(type != TxnType.transfer);
  final byCat = <String, double>{};
  final wanted = type == TxnType.income ? TransferDirection.incoming : TransferDirection.outgoing;
  var uncategorised = 0.0;
  var transfers = 0.0;
  for (final t in txns) {
    if (!t.isCounted) continue;
    if (range != null && !range.contains(t.date)) continue;
    if (t.isTransfer) {
      if (t.direction == wanted) transfers += t.amount;
      continue;
    }
    if (t.type != type) continue;
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
  final total = sorted.fold<double>(uncategorised + transfers, (s, e) => s + e.value);
  if (total <= 0) return Breakdown.empty;

  final entries = <BreakdownEntry>[
    for (final e in sorted.take(top)) BreakdownEntry(e.key, e.value),
  ];
  if (transfers > 0.005) {
    // Placed by size, after any category of the same amount.
    final at = entries.indexWhere((e) => e.amount < transfers);
    entries.insert(at < 0 ? entries.length : at, BreakdownEntry.transfers(transfers));
  }
  final rest = sorted.skip(top).fold<double>(uncategorised, (s, e) => s + e.value);
  if (rest > 0.005) entries.add(BreakdownEntry(null, rest));
  return Breakdown(total, entries);
}
