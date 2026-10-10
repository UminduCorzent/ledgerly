// foundation.dart has its own `Category` annotation; hide it to keep the name free.
import 'package:flutter/foundation.dart' hide Category;

import '../core/strings/app_strings.dart';
import '../data/db.dart';
import '../domain/date_range.dart';
import '../domain/ledger_math.dart';
import '../domain/txn_query.dart';
import '../models/txn.dart';
import 'error_reporter.dart';
import 'ledger_store.dart';

enum PeriodKind { month, all, custom }

/// The Transactions tab's result: list items plus the summary figures.
@immutable
class QueryResult {
  const QueryResult({
    required this.items,
    required this.count,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.excludedCount,
    required this.mixedCurrencies,
    required this.currency,
    required this.multiAccount,
    required this.grouped,
  });

  /// [DayGroup] headers followed by their [Txn] rows when [grouped]; otherwise just rows.
  final List<Object> items;
  final int count;
  final double income;
  final double expense;

  /// Gross amount moved by transfer rows (direction ignored).
  final double transfer;
  final int excludedCount;
  final bool mixedCurrencies;

  /// The single currency of the rows (valid only when not [mixedCurrencies]).
  final String currency;
  final bool multiAccount;
  final bool grouped;
}

/// Period, filters, search and sort for the Transactions tab. Shared app-wide so
/// Home can open the list pre-filtered. Resets when the active account changes.
class TxnFilterStore extends ChangeNotifier {
  TxnFilterStore(this._ledger, this._db) {
    _sort = TxnSort.parse(_db.setting<String>(_kSort));
    _forAccount = _ledger.activeAccount?.id;
    _ledger.addListener(_onLedgerChanged);
  }

  final LedgerStore _ledger;
  final Db _db;
  static const String _kSort = 'txnSort';

  PeriodKind _kind = PeriodKind.month;
  DateTime _monthAnchor = DateTime.now();
  DateRange? _custom;
  DatePreset? _customPreset;
  TxnFilter _filter = TxnFilter.none;
  String _query = '';
  late TxnSort _sort;
  String? _forAccount;
  int _version = 0;

  PeriodKind get kind => _kind;
  DateTime get monthAnchor => _monthAnchor;
  DatePreset? get customPreset => _customPreset;
  TxnFilter get filter => _filter;
  String get query => _query;
  TxnSort get sort => _sort;

  bool get hasFilters => !_filter.isEmpty || _query.trim().isNotEmpty;

  /// The date range in effect (null = all time).
  DateRange? get range => switch (_kind) {
        PeriodKind.month => _cycleOf(_monthAnchor),
        PeriodKind.all => null,
        PeriodKind.custom => _custom,
      };

  DateRange _cycleOf(DateTime d) {
    final id = _ledger.activeAccount?.id;
    return id == null ? DateRange(d) : _ledger.cycleContaining(id, d);
  }

  /// Exposed for the Filter sheet's date presets.
  DateRange cycleOf(DateTime d) => _cycleOf(d);

  @override
  void dispose() {
    _ledger.removeListener(_onLedgerChanged);
    super.dispose();
  }

  void _onLedgerChanged() {
    final id = _ledger.activeAccount?.id;
    if (id != _forAccount) {
      _forAccount = id;
      _kind = PeriodKind.month;
      _monthAnchor = DateTime.now();
      _custom = null;
      _customPreset = null;
      _filter = TxnFilter.none;
      _query = '';
      _bump();
    }
  }

  void _bump() {
    _version++;
    _resultKey = null;
    notifyListeners();
  }

  // ------------------------------------------------------------- mutations

  void setQuery(String q) {
    if (q == _query) return;
    _query = q;
    _bump();
  }

  void setFilter(TxnFilter f) {
    _filter = f;
    _bump();
  }

  void clearFilters() {
    _filter = TxnFilter.none;
    _query = '';
    if (_kind == PeriodKind.custom) {
      _kind = PeriodKind.month;
      _monthAnchor = DateTime.now();
      _custom = null;
      _customPreset = null;
    }
    _bump();
  }

  Future<void> setSort(TxnSort s) async {
    if (s == _sort) return;
    _sort = s;
    _bump();
    try {
      await _db.setSetting(_kSort, s.name);
    } catch (_) {
      ErrorReporter.saveFailed();
    }
  }

  void showMonth(DateTime anchor) {
    _kind = PeriodKind.month;
    _monthAnchor = anchor;
    _custom = null;
    _customPreset = null;
    _bump();
  }

  /// Moves the month navigator by whole cycles.
  void shiftMonth(int delta) {
    final current = _kind == PeriodKind.month ? _cycleOf(_monthAnchor) : _cycleOf(DateTime.now());
    var anchor = current.start;
    if (delta < 0) {
      for (var i = 0; i < -delta; i++) {
        anchor = _cycleOf(DateTime(anchor.year, anchor.month, anchor.day - 1)).start;
      }
    } else {
      for (var i = 0; i < delta; i++) {
        final end = _cycleOf(anchor).end ?? DateTime(anchor.year, anchor.month + 1, anchor.day);
        anchor = end;
      }
    }
    showMonth(anchor);
  }

  void showAllTime() {
    _kind = PeriodKind.all;
    _custom = null;
    _customPreset = null;
    _bump();
  }

  void showCustom(DateRange r, {DatePreset? preset}) {
    _kind = PeriodKind.custom;
    _custom = r;
    _customPreset = preset;
    _bump();
  }

  void applyPreset(DatePreset p) {
    final now = DateTime.now();
    switch (p) {
      case DatePreset.thisMonth:
        showMonth(now);
      case DatePreset.lastMonth:
        {
          final c = _cycleOf(now);
          showMonth(DateTime(c.start.year, c.start.month, c.start.day - 1));
        }
      case DatePreset.allTime:
        showAllTime();
      default:
        {
          final r = presetRange(p, now, _cycleOf);
          if (r != null) showCustom(r, preset: p);
        }
    }
  }

  /// Applies everything from the Filter sheet at once.
  void applyAll({required TxnFilter filter, required PeriodKind kind, DateTime? anchor, DateRange? custom, DatePreset? preset}) {
    _filter = filter;
    _kind = kind;
    if (anchor != null) _monthAnchor = anchor;
    _custom = kind == PeriodKind.custom ? custom : null;
    _customPreset = kind == PeriodKind.custom ? preset : null;
    _bump();
  }

  /// Home → Transactions jumps (income/expense pill, breakdown row).
  ///
  /// Home counts incoming transfers as income and outgoing ones as expense, so
  /// the Income/Expense pills open their type plus transfers in that direction,
  /// and [transfersOnly] (the breakdown's Transfers slice) opens just those.
  void openFromHome({
    TxnType? type,
    String? categoryName,
    bool transfersOnly = false,
    required bool allTime,
  }) {
    final dir = switch (type) {
      TxnType.income => TransferDirection.incoming,
      TxnType.expense => TransferDirection.outgoing,
      _ => null,
    };
    _filter = TxnFilter(
      types: type == null
          ? const {}
          : transfersOnly
              ? const {TxnType.transfer}
              : categoryName != null
                  ? {type}
                  : {type, TxnType.transfer},
      categoryNames: categoryName == null ? const {} : {categoryName.toLowerCase()},
      transferDirection: categoryName == null ? dir : null,
    );
    _query = '';
    _custom = null;
    _customPreset = null;
    _kind = allTime ? PeriodKind.all : PeriodKind.month;
    _monthAnchor = DateTime.now();
    _bump();
  }

  // ----------------------------------------------------------------- query

  String? _resultKey;
  QueryResult? _result;

  List<Txn> _scope(TxnFilter f) {
    final active = _ledger.activeAccount?.id;
    final ids = f.accountIds.isEmpty ? {if (active != null) active} : f.accountIds;
    if (ids.length == 1) return _ledger.txnsFor(ids.first);
    return [for (final id in ids) ..._ledger.txnsFor(id)];
  }

  String _catName(Txn t) => _ledger.categoryNameOf(t, AppStrings.current.typeTransfer);

  String _accName(Txn t) => _ledger.account(t.accountId)?.name ?? '';

  /// Live count for the Filter sheet before it is applied.
  int countFor(TxnFilter f, DateRange? r) => _scope(f)
      .where((t) => txnMatches(t, f, range: r, query: _query, categoryName: _catName))
      .length;

  /// The current list and summary, memoised until the data or the filters change.
  QueryResult get result {
    final key = '${_ledger.version}:$_version';
    final cached = _result;
    if (cached != null && _resultKey == key) return cached;

    final f = _filter;
    final r = range;
    final rows = _scope(f)
        .where((t) => txnMatches(t, f, range: r, query: _query, categoryName: _catName))
        .toList()
      ..sort(txnComparator(_sort, categoryName: _catName, accountName: _accName));

    var income = 0.0, expense = 0.0, transfer = 0.0;
    var excluded = 0;
    final currencies = <String>{};
    final accounts = <String>{};
    for (final t in rows) {
      accounts.add(t.accountId);
      currencies.add(_ledger.account(t.accountId)?.currency ?? '');
      if (!t.isCounted) {
        excluded++;
        continue;
      }
      switch (t.type) {
        case TxnType.income:
          income += t.amount;
        case TxnType.expense:
          expense += t.amount;
        case TxnType.transfer:
          // Counts as money in / out, the same as Home's figures.
          transfer += t.amount;
          if (t.direction == TransferDirection.outgoing) {
            expense += t.amount;
          } else {
            income += t.amount;
          }
      }
    }
    final mixed = currencies.length > 1;
    final currency = currencies.isEmpty
        ? (_ledger.activeAccount?.currency ?? '')
        : currencies.first;

    final grouped = _sort.isChronological;
    final List<Object> items;
    if (grouped) {
      items = <Object>[];
      DateTime? day;
      var bucket = <Txn>[];
      void flush() {
        final d = day;
        if (d == null || bucket.isEmpty) return;
        items.add(DayGroup(d, List.unmodifiable(bucket), totalsOf(bucket).net));
        items.addAll(bucket);
      }

      for (final t in rows) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        if (d != day) {
          flush();
          day = d;
          bucket = <Txn>[];
        }
        bucket.add(t);
      }
      flush();
    } else {
      items = rows;
    }

    final res = QueryResult(
      items: List.unmodifiable(items),
      count: rows.length,
      income: income,
      expense: expense,
      transfer: transfer,
      excludedCount: excluded,
      mixedCurrencies: mixed,
      currency: currency,
      multiAccount: accounts.length > 1 || f.accountIds.length > 1,
      grouped: grouped,
    );
    _result = res;
    _resultKey = key;
    return res;
  }
}
