import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/domain/category_merge.dart';

Map<String, dynamic> _cat(String id, String acc, String name, int order, {String emoji = '📌'}) => {
      'id': id,
      'accountId': acc,
      'name': name,
      'emoji': emoji,
      'color': 0,
      'sortOrder': order,
      'createdAt': 0,
    };

Map<String, dynamic> _txn(String id, String acc, String cat) => {
      'id': id,
      'accountId': acc,
      'type': 'expense',
      'amount': 1.0,
      'categoryId': cat,
    };

void main() {
  // "Bank" comes before "Cash" in the account order, whatever the map order.
  final accounts = [
    {'id': 'cash', 'sortOrder': 1},
    {'id': 'bank', 'sortOrder': 0},
  ];
  final categories = [
    _cat('cFood', 'cash', 'food ', 0, emoji: '🍔'),
    _cat('cFuel', 'cash', 'Fuel', 1),
    _cat('bFood', 'bank', 'Food', 0, emoji: '🍽️'),
    _cat('bSalary', 'bank', 'Salary', 1),
  ];
  final txns = [
    _txn('t1', 'cash', 'cFood'),
    _txn('t2', 'bank', 'bFood'),
    _txn('t3', 'cash', 'cFuel'),
  ];
  final settings = <String, dynamic>{
    'defaultCat_expense_cash': 'cFood',
    'defaultCat_income_bank': 'bSalary',
    'cycle_cash': {
      'mode': 'payday',
      'anchorCategoryIds': ['cFood', 'bFood'],
    },
    'themeMode': 'dark',
  };

  MergeResult run() => mergeCategoriesAcrossAccounts(
        accounts: accounts,
        categories: categories,
        txns: txns,
        settings: settings,
      );

  test('same-named categories merge; the first account in order wins', () {
    final r = run();
    expect(r.changed, isTrue);
    expect([for (final c in r.categories) c['id']], ['bFood', 'bSalary', 'cFuel']);
    expect([for (final c in r.categories) c['sortOrder']], [0, 1, 2]);
    expect(r.categories.first['emoji'], '🍽️');
    expect(r.categories.every((c) => !c.containsKey('accountId')), isTrue);
    expect(r.removedIds, {'cFood'});
  });

  test('transactions, defaults and payday categories follow the merge', () {
    final r = run();
    expect(r.changedTxns.keys, ['t1']);
    expect(r.changedTxns['t1']!['categoryId'], 'bFood');
    final all = r.applyToTxns(txns);
    expect([for (final t in all) t['categoryId']], ['bFood', 'bFood', 'cFuel']);
    expect(r.changedSettings['defaultCat_expense_cash'], 'bFood');
    expect(r.changedSettings.containsKey('defaultCat_income_bank'), isFalse);
    expect((r.changedSettings['cycle_cash'] as Map)['anchorCategoryIds'], ['bFood']);
    expect((r.changedSettings['cycle_cash'] as Map)['mode'], 'payday');
    expect(r.changedSettings.containsKey('themeMode'), isFalse);
  });

  test('running it again changes nothing', () {
    final first = run();
    final again = mergeCategoriesAcrossAccounts(
      accounts: accounts,
      categories: first.categories,
      txns: first.applyToTxns(txns),
      settings: {...settings, ...first.changedSettings},
    );
    expect(again.changed, isFalse);
    expect(again.removedIds, isEmpty);
    expect(again.changedTxns, isEmpty);
    expect(again.changedSettings, isEmpty);
  });
}
