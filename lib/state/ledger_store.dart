import 'package:collection/collection.dart';
// foundation.dart has its own `Category` annotation, which clashes with our model.
import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';

import '../core/strings/app_strings.dart';
import '../data/change_set.dart';
import '../data/db.dart';
import '../domain/date_range.dart';
import '../domain/ledger_math.dart';
import '../domain/month_cycle.dart';
import '../domain/seeds.dart';
import '../domain/transfer_rules.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/txn.dart';
import 'error_reporter.dart';
import 'write_result.dart';

/// What the Add/Edit sheet produces. For transfers, [accountId] is the source,
/// [toAccountId] the destination and [received] the amount arriving there.
@immutable
class TxnDraft {
  const TxnDraft({
    required this.type,
    required this.accountId,
    required this.amount,
    required this.description,
    required this.date,
    this.toAccountId,
    this.received,
    this.categoryId,
    this.notes,
    this.excluded = false,
  });

  final TxnType type;
  final String accountId;
  final String? toAccountId;
  final double amount;
  final double? received;
  final String? categoryId;
  final String description;
  final DateTime date;
  final String? notes;
  final bool excluded;
}

@immutable
class HomeSummary {
  const HomeSummary(this.range, this.totals);

  /// Null for "All time".
  final DateRange? range;
  final PeriodTotals totals;

  double get balance => totals.net;
}

@immutable
class DayGroup {
  const DayGroup(this.day, this.txns, this.net);

  final DateTime day;
  final List<Txn> txns;

  /// Counted net effect of the day's rows on the account.
  final double net;
}

/// The single source of truth for accounts, categories and transactions.
///
/// Everything derived (sorted lists, totals, breakdowns, day groups) is memoised
/// per data [version], so widgets can read it freely in `build()` without
/// recomputing.
class LedgerStore extends ChangeNotifier {
  LedgerStore(this._db);

  final Db _db;
  static const Uuid _uuid = Uuid();
  static const String _kActive = 'activeAccountId';

  String newId() => _uuid.v4();

  final Map<String, Account> _accounts = {};
  final Map<String, Category> _categories = {};
  final Map<String, Txn> _txns = {};
  String? _activeId;
  int _version = 0;
  final Map<String, Object?> _memo = {};

  int get version => _version;

  // ---------------------------------------------------------------- loading

  void load() {
    _accounts
      ..clear()
      ..addEntries(_db.all(Db.accounts).map((m) {
        final a = Account.fromMap(m);
        return MapEntry(a.id, a);
      }));
    _categories
      ..clear()
      ..addEntries(_db.all(Db.categories).map((m) {
        final c = Category.fromMap(m);
        return MapEntry(c.id, c);
      }));
    _txns
      ..clear()
      ..addEntries(_db.all(Db.txns).map((m) {
        final t = Txn.fromMap(m);
        return MapEntry(t.id, t);
      }));
    _activeId = _db.setting<String>(_kActive);
    _changed();
  }

  void _changed() {
    _version++;
    _memo.clear();
    notifyListeners();
  }

  T _cached<T>(String key, T Function() build) {
    if (_memo.containsKey(key)) return _memo[key] as T;
    final v = build();
    _memo[key] = v;
    return v;
  }

  // ------------------------------------------------------------------ reads

  bool get hasAccounts => _accounts.isNotEmpty;

  List<Account> get accounts => _cached('accounts', () {
        final list = _accounts.values.toList()
          ..sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
          });
        return List<Account>.unmodifiable(list);
      });

  Account? get activeAccount {
    final a = _accounts[_activeId];
    if (a != null) return a;
    final list = accounts;
    return list.isEmpty ? null : list.first;
  }

  Account? account(String? id) => id == null ? null : _accounts[id];
  Category? category(String? id) => id == null ? null : _categories[id];
  Txn? txn(String id) => _txns[id];

  List<Category> categoriesFor(String accountId) => _cached('cats:$accountId', () {
        final list = _categories.values.where((c) => c.accountId == accountId).toList()
          ..sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return List<Category>.unmodifiable(list);
      });

  /// Newest first.
  List<Txn> txnsFor(String accountId) => _cached('txns:$accountId', () {
        final list = _txns.values.where((t) => t.accountId == accountId).toList()
          ..sort((a, b) {
            final c = b.date.compareTo(a.date);
            return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
          });
        return List<Txn>.unmodifiable(list);
      });

  Map<String, List<Txn>> get _byTransfer => _cached('byTransfer', () {
        final map = <String, List<Txn>>{};
        for (final t in _txns.values) {
          final id = t.transferId;
          if (id != null) (map[id] ??= []).add(t);
        }
        return map;
      });

  /// The other leg of a transfer.
  Txn? counterpart(Txn t) {
    final id = t.transferId;
    if (id == null) return null;
    return _byTransfer[id]?.firstWhereOrNull((o) => o.id != t.id);
  }

  /// All-time balance.
  double balanceOf(String accountId) =>
      _cached('bal:$accountId', () => totalsOf(txnsFor(accountId)).net);

  /// Balance totals per currency across every account (never mixed).
  Map<String, double> totalsByCurrency() => _cached('byCurrency', () {
        final map = <String, double>{};
        for (final a in accounts) {
          map[a.currency] = (map[a.currency] ?? 0) + balanceOf(a.id);
        }
        return map;
      });

  /// The month cycle containing [date] for [accountId]. Calendar month for now;
  /// the per-account month-cycle setting plugs in here.
  DateRange cycleContaining(String accountId, DateTime date) => fixedDayCycle(date, 1);

  /// The current "This month" for [accountId].
  DateRange currentCycle(String accountId, DateTime now) => cycleContaining(accountId, now);

  /// Display name used for search, sort and category filters. Transfers have no
  /// category, so they use [transferLabel].
  String categoryNameOf(Txn t, String transferLabel) =>
      t.isTransfer ? transferLabel : (category(t.categoryId)?.name ?? '');

  /// Transaction count per category id for one account (excluded rows included).
  Map<String, int> categoryUsage(String accountId) => _cached('catUsage:$accountId', () {
        final map = <String, int>{};
        for (final t in txnsFor(accountId)) {
          final id = t.categoryId;
          if (id != null) map[id] = (map[id] ?? 0) + 1;
        }
        return map;
      });

  bool isCategoryNameTaken(String accountId, String name, {String? exceptId}) {
    final lower = name.trim().toLowerCase();
    return _categories.values.any(
      (c) => c.accountId == accountId && c.id != exceptId && c.name.toLowerCase() == lower,
    );
  }

  /// The user's saved default for [type], if it still exists.
  String? savedDefaultCategoryId(String accountId, TxnType type) {
    final saved = _db.setting<String>(_defaultKey(accountId, type));
    return saved != null && _categories[saved]?.accountId == accountId ? saved : null;
  }

  static String _defaultKey(String accountId, TxnType type) => 'defaultCat_${type.name}_$accountId';

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  HomeSummary summary(String accountId, {required bool allTime, required DateTime now}) =>
      _cached('sum:$accountId:$allTime:${_dayKey(now)}', () {
        final range = allTime ? null : currentCycle(accountId, now);
        return HomeSummary(range, totalsOf(txnsFor(accountId), range));
      });

  Breakdown breakdown(
    String accountId,
    TxnType type, {
    required bool allTime,
    required DateTime now,
  }) =>
      _cached('bd:$accountId:${type.name}:$allTime:${_dayKey(now)}', () {
        final range = allTime ? null : currentCycle(accountId, now);
        return breakdownOf(txnsFor(accountId), type, range: range);
      });

  /// Transactions grouped by calendar day, newest day first.
  List<DayGroup> dayGroups(String accountId) => _cached('days:$accountId', () {
        final groups = <DayGroup>[];
        DateTime? day;
        var bucket = <Txn>[];
        void flush() {
          final d = day;
          if (d == null || bucket.isEmpty) return;
          groups.add(DayGroup(d, List.unmodifiable(bucket), totalsOf(bucket).net));
        }

        for (final t in txnsFor(accountId)) {
          final d = DateTime(t.date.year, t.date.month, t.date.day);
          if (d != day) {
            flush();
            day = d;
            bucket = <Txn>[];
          }
          bucket.add(t);
        }
        flush();
        return List<DayGroup>.unmodifiable(groups);
      });

  /// [dayGroups] flattened for a lazy list: each [DayGroup] header followed by its [Txn] rows.
  List<Object> dayListItems(String accountId) => _cached('dayItems:$accountId', () {
        final items = <Object>[];
        for (final g in dayGroups(accountId)) {
          items
            ..add(g)
            ..addAll(g.txns);
        }
        return List<Object>.unmodifiable(items);
      });

  int txnCount(String accountId) => txnsFor(accountId).length;

  int transferCount(String accountId) =>
      txnsFor(accountId).where((t) => t.isTransfer).length;

  bool isAccountNameTaken(String name, {String? exceptId}) {
    final lower = name.trim().toLowerCase();
    return _accounts.values.any((a) => a.id != exceptId && a.name.toLowerCase() == lower);
  }

  /// The category preselected in the Add sheet for [type].
  String? defaultCategoryId(String accountId, TxnType type) {
    final saved = savedDefaultCategoryId(accountId, type);
    if (saved != null) return saved;
    final cats = categoriesFor(accountId);
    if (cats.isEmpty) return null;
    final seedIndex = type == TxnType.income ? kSeedIncomeDefault : kSeedExpenseDefault;
    final name = AppStrings.current.seedCategoryNames[seedIndex].toLowerCase();
    return (cats.firstWhereOrNull((c) => c.name.toLowerCase() == name) ?? cats.first).id;
  }

  // ----------------------------------------------------------------- writes

  Future<WriteResult> _commit(ChangeSet cs) async {
    if (cs.isEmpty) return WriteResult.ok(ChangeSet());
    try {
      final inverse = await _db.apply(cs);
      _applyInMemory(cs);
      _changed();
      return WriteResult.ok(inverse);
    } catch (e) {
      debugPrint('Ledger write failed: $e');
      load();
      ErrorReporter.saveFailed();
      return WriteResult.fail(e);
    }
  }

  void _applyInMemory(ChangeSet cs) {
    cs.ops.forEach((box, items) {
      items.forEach((id, v) {
        switch (box) {
          case Db.accounts:
            if (v == null) {
              _accounts.remove(id);
            } else {
              _accounts[id] = Account.fromMap(v);
            }
          case Db.categories:
            if (v == null) {
              _categories.remove(id);
            } else {
              _categories[id] = Category.fromMap(v);
            }
          case Db.txns:
            if (v == null) {
              _txns.remove(id);
            } else {
              _txns[id] = Txn.fromMap(v);
            }
        }
      });
    });
  }

  /// Reverses a previous write (the inverse returned in [WriteResult.undo]).
  Future<WriteResult> undo(ChangeSet inverse) => _commit(inverse);

  Future<void> setActive(String id) async {
    if (_activeId == id || !_accounts.containsKey(id)) return;
    _activeId = id;
    _changed();
    try {
      await _db.setSetting(_kActive, id);
    } catch (_) {
      ErrorReporter.saveFailed();
    }
  }

  // Accounts

  Future<WriteResult> createAccount({
    required String name,
    required String currency,
    required String emoji,
    required int color,
    required AccountType type,
  }) async {
    final now = DateTime.now();
    final id = newId();
    final list = accounts;
    final account = Account(
      id: id,
      name: name.trim(),
      currency: currency,
      emoji: emoji,
      color: color,
      type: type,
      sortOrder: list.isEmpty ? 0 : list.last.sortOrder + 1,
      createdAt: now,
    );
    final cs = ChangeSet()..put(Db.accounts, id, account.toMap());
    final names = AppStrings.current.seedCategoryNames;
    for (var i = 0; i < kSeedCategories.length; i++) {
      final c = Category(
        id: newId(),
        accountId: id,
        name: names[i],
        emoji: kSeedCategories[i].$1,
        color: kSeedCategories[i].$2,
        sortOrder: i,
        createdAt: now,
      );
      cs.put(Db.categories, c.id, c.toMap());
    }
    final r = await _commit(cs);
    if (r.success && (_activeId == null || !_accounts.containsKey(_activeId))) {
      await setActive(id);
    }
    return r;
  }

  Future<WriteResult> updateAccount(Account a) =>
      _commit(ChangeSet()..put(Db.accounts, a.id, a.copyWith(name: a.name.trim()).toMap()));

  Future<WriteResult> reorderAccounts(List<String> orderedIds) {
    final cs = ChangeSet();
    for (var i = 0; i < orderedIds.length; i++) {
      final a = _accounts[orderedIds[i]];
      if (a != null && a.sortOrder != i) cs.put(Db.accounts, a.id, a.copyWith(sortOrder: i).toMap());
    }
    return _commit(cs);
  }

  /// Deletes an account. See [planAccountDeletion] for what happens to its
  /// transactions and transfers. The whole change is one write, so Undo restores all of it.
  Future<WriteResult> deleteAccount(String id, {String? reassignToId}) async {
    final acc = _accounts[id];
    if (acc == null || _accounts.length <= 1) {
      return WriteResult.fail(StateError('cannot delete'));
    }
    final s = AppStrings.current;
    final plan = planAccountDeletion(
      accountId: id,
      accountName: acc.name,
      txns: _txns.values.toList(),
      categories: _categories.values.toList(),
      reassignToId: reassignToId,
      newId: newId,
      now: DateTime.now(),
      labels: DeletionLabels(
        transfersCategoryName: s.transfersCategory,
        transferFrom: s.transferFromAccount,
        transferTo: s.transferToAccount,
      ),
    );
    final cs = ChangeSet()..delete(Db.accounts, id);
    for (final t in plan.putTxns) {
      cs.put(Db.txns, t.id, t.toMap());
    }
    for (final tid in plan.deleteTxnIds) {
      cs.delete(Db.txns, tid);
    }
    for (final c in plan.putCategories) {
      cs.put(Db.categories, c.id, c.toMap());
    }
    for (final cid in plan.deleteCategoryIds) {
      cs.delete(Db.categories, cid);
    }
    final wasActive = activeAccount?.id == id;
    final r = await _commit(cs);
    if (r.success && wasActive) {
      final remaining = accounts;
      final next = reassignToId != null
          ? _accounts[reassignToId]
          : (remaining.isEmpty ? null : remaining.first);
      if (next != null) await setActive(next.id);
    }
    return r;
  }

  // Transactions

  /// Adds or replaces a transaction. Editing a transfer rewrites both legs;
  /// switching a row between transfer and non-transfer replaces it.
  Future<WriteResult> saveDraft(TxnDraft d, {Txn? editing}) {
    final now = DateTime.now();
    final cs = ChangeSet();
    final editOther = editing == null ? null : counterpart(editing);
    final createdAt = editing?.createdAt ?? now;
    final updatedAt = editing == null ? null : now;

    if (d.type == TxnType.transfer) {
      var transferId = newId();
      var outId = newId();
      var inId = newId();
      if (editing != null && editing.isTransfer) {
        final outLeg = editing.direction == TransferDirection.outgoing ? editing : editOther;
        final inLeg = editing.direction == TransferDirection.outgoing ? editOther : editing;
        transferId = editing.transferId ?? transferId;
        if (outLeg != null) outId = outLeg.id;
        if (inLeg != null) inId = inLeg.id;
      } else if (editing != null) {
        cs.delete(Db.txns, editing.id);
      }
      final legs = buildTransferLegs(
        transferId: transferId,
        outId: outId,
        inId: inId,
        fromAccountId: d.accountId,
        toAccountId: d.toAccountId!,
        sent: d.amount,
        received: d.received ?? d.amount,
        date: d.date,
        description: d.description,
        notes: d.notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      for (final leg in legs) {
        cs.put(Db.txns, leg.id, leg.toMap());
      }
    } else {
      var id = newId();
      if (editing != null) {
        if (editing.isTransfer) {
          cs.delete(Db.txns, editing.id);
          if (editOther != null) cs.delete(Db.txns, editOther.id);
        } else {
          id = editing.id;
        }
      }
      final t = Txn(
        id: id,
        accountId: d.accountId,
        type: d.type,
        amount: d.amount,
        categoryId: d.categoryId,
        description: d.description,
        date: d.date,
        notes: d.notes,
        excluded: d.excluded,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      cs.put(Db.txns, id, t.toMap());
    }
    return _commit(cs);
  }

  /// Deletes a transaction; for a transfer, both legs.
  Future<WriteResult> deleteTxn(String id) => deleteTxns([id]);

  /// Deletes several transactions in one write (one Undo). Transfers take both legs.
  Future<WriteResult> deleteTxns(Iterable<String> ids) {
    final cs = ChangeSet();
    for (final id in ids) {
      final t = _txns[id];
      if (t == null) continue;
      cs.delete(Db.txns, t.id);
      final other = counterpart(t);
      if (other != null) cs.delete(Db.txns, other.id);
    }
    return _commit(cs);
  }

  // Categories

  Future<WriteResult> createCategory({
    required String accountId,
    required String name,
    required String emoji,
    required int color,
  }) {
    final existing = categoriesFor(accountId);
    final maxOrder = existing.fold<int>(-1, (m, c) => c.sortOrder > m ? c.sortOrder : m);
    final c = Category(
      id: newId(),
      accountId: accountId,
      name: name.trim(),
      emoji: emoji,
      color: color,
      // New categories go to the end of the list.
      sortOrder: maxOrder + 1,
      createdAt: DateTime.now(),
    );
    return _commit(ChangeSet()..put(Db.categories, c.id, c.toMap()));
  }

  Future<WriteResult> updateCategory(Category c) =>
      _commit(ChangeSet()..put(Db.categories, c.id, c.copyWith(name: c.name.trim()).toMap()));

  Future<WriteResult> reorderCategories(List<String> orderedIds) {
    final cs = ChangeSet();
    for (var i = 0; i < orderedIds.length; i++) {
      final c = _categories[orderedIds[i]];
      if (c != null && c.sortOrder != i) cs.put(Db.categories, c.id, c.copyWith(sortOrder: i).toMap());
    }
    return _commit(cs);
  }

  /// Deletes categories. Their transactions move to [reassignToId], or are deleted
  /// when it is null. Defaults pointing at a deleted category are cleared.
  Future<WriteResult> deleteCategories(Set<String> ids, {String? reassignToId}) async {
    final now = DateTime.now();
    final cs = ChangeSet();
    final accountIds = <String>{};
    for (final id in ids) {
      final c = _categories[id];
      if (c == null) continue;
      accountIds.add(c.accountId);
      cs.delete(Db.categories, id);
    }
    for (final t in _txns.values) {
      if (t.categoryId == null || !ids.contains(t.categoryId)) continue;
      if (reassignToId == null) {
        cs.delete(Db.txns, t.id);
      } else {
        cs.put(Db.txns, t.id, t.copyWith(categoryId: reassignToId, updatedAt: now).toMap());
      }
    }
    final r = await _commit(cs);
    if (r.success) {
      for (final acc in accountIds) {
        for (final type in [TxnType.expense, TxnType.income]) {
          final key = _defaultKey(acc, type);
          if (ids.contains(_db.setting<String>(key))) {
            try {
              await _db.setSetting(key, null);
            } catch (_) {
              // A stale default is harmless: the Add sheet falls back automatically.
            }
          }
        }
      }
    }
    return r;
  }

  Future<void> setDefaultCategory(String accountId, TxnType type, String categoryId) async {
    try {
      await _db.setSetting(_defaultKey(accountId, type), categoryId);
    } catch (_) {
      ErrorReporter.saveFailed();
    }
    _changed();
  }
}
