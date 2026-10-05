import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/domain/date_range.dart';
import 'package:ledgerly/domain/month_cycle.dart';
import 'package:ledgerly/domain/txn_query.dart';
import 'package:ledgerly/models/txn.dart';

Txn _t(
  String id,
  TxnType type,
  double amount, {
  String cat = 'Food',
  String account = 'a',
  DateTime? date,
  bool excluded = false,
  String? notes,
}) =>
    Txn(
      id: id,
      accountId: account,
      type: type,
      amount: amount,
      categoryId: cat,
      description: 'desc $id',
      notes: notes,
      date: date ?? DateTime(2026, 10, 5),
      createdAt: DateTime(2026, 10, 5),
      excluded: excluded,
      direction: type == TxnType.transfer ? TransferDirection.outgoing : null,
    );

// In these tests the categoryId doubles as the category name.
String _name(Txn t) => t.isTransfer ? 'Transfer' : (t.categoryId ?? '');

void main() {
  group('txnMatches', () {
    test('types OR inside the group, AND across groups', () {
      final f = TxnFilter(types: {TxnType.income, TxnType.expense}, categoryNames: {'food'});
      expect(txnMatches(_t('1', TxnType.expense, 5), f, categoryName: _name), isTrue);
      expect(txnMatches(_t('2', TxnType.income, 5, cat: 'Salary'), f, categoryName: _name), isFalse);
      expect(txnMatches(_t('3', TxnType.transfer, 5), f, categoryName: _name), isFalse);
    });

    test('amount bounds are inclusive', () {
      const f = TxnFilter(minAmount: 10, maxAmount: 20);
      expect(txnMatches(_t('a', TxnType.expense, 10), f, categoryName: _name), isTrue);
      expect(txnMatches(_t('b', TxnType.expense, 20), f, categoryName: _name), isTrue);
      expect(txnMatches(_t('c', TxnType.expense, 20.01), f, categoryName: _name), isFalse);
    });

    test('counting filter; transfers always count', () {
      const counted = TxnFilter(counting: CountingFilter.counted);
      const excluded = TxnFilter(counting: CountingFilter.excluded);
      final x = _t('x', TxnType.expense, 5, excluded: true);
      final tr = _t('t', TxnType.transfer, 5, excluded: true);
      expect(txnMatches(x, counted, categoryName: _name), isFalse);
      expect(txnMatches(x, excluded, categoryName: _name), isTrue);
      expect(txnMatches(tr, excluded, categoryName: _name), isFalse);
    });

    test('search covers description, category and notes', () {
      final t = _t('n', TxnType.expense, 5, cat: 'Groceries', notes: 'Weekly SHOP');
      expect(txnMatches(t, TxnFilter.none, query: 'desc n', categoryName: _name), isTrue);
      expect(txnMatches(t, TxnFilter.none, query: 'grocer', categoryName: _name), isTrue);
      expect(txnMatches(t, TxnFilter.none, query: 'shop', categoryName: _name), isTrue);
      expect(txnMatches(t, TxnFilter.none, query: 'rent', categoryName: _name), isFalse);
    });

    test('range is applied', () {
      final r = DateRange(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
      expect(
        txnMatches(_t('o', TxnType.expense, 1, date: DateTime(2026, 9, 30)), TxnFilter.none,
            range: r, categoryName: _name),
        isFalse,
      );
    });

    test('active filter count', () {
      expect(TxnFilter.none.activeCount, 0);
      const f = TxnFilter(types: {TxnType.income}, minAmount: 1, counting: CountingFilter.excluded);
      expect(f.activeCount, 3);
      expect(f.copyWith(minAmount: null).activeCount, 2);
    });
  });

  group('sorting', () {
    final rows = [
      _t('a', TxnType.expense, 30, cat: 'Rent', date: DateTime(2026, 10, 1)),
      _t('b', TxnType.income, 10, cat: 'Salary', date: DateTime(2026, 10, 3)),
      _t('c', TxnType.transfer, 20, date: DateTime(2026, 10, 2)),
    ];
    List<String> ids(TxnSort s) => (List.of(rows)
          ..sort(txnComparator(s, categoryName: _name, accountName: (t) => t.accountId)))
        .map((t) => t.id)
        .toList();

    test('date, amount, category and type orders', () {
      expect(ids(TxnSort.dateDesc), ['b', 'c', 'a']);
      expect(ids(TxnSort.dateAsc), ['a', 'c', 'b']);
      expect(ids(TxnSort.amountDesc), ['a', 'c', 'b']);
      expect(ids(TxnSort.amountAsc), ['b', 'c', 'a']);
      expect(ids(TxnSort.categoryAsc), ['a', 'b', 'c']); // Rent, Salary, Transfer
      expect(ids(TxnSort.typeAsc), ['b', 'a', 'c']); // income, expense, transfer
      expect(ids(TxnSort.typeDesc), ['c', 'a', 'b']);
      expect(TxnSort.dateAsc.isChronological, isTrue);
      expect(TxnSort.amountAsc.isChronological, isFalse);
    });

    test('unknown stored sort falls back to newest first', () {
      expect(TxnSort.parse('nope'), TxnSort.dateDesc);
      expect(TxnSort.parse('amountAsc'), TxnSort.amountAsc);
    });
  });

  group('date presets', () {
    final now = DateTime(2026, 10, 7, 15); // a Wednesday
    DateRange calendar(DateTime d) => fixedDayCycle(d, 1);

    test('today and this week (Monday start)', () {
      expect(presetRange(DatePreset.today, now, calendar),
          DateRange(DateTime(2026, 10, 7), DateTime(2026, 10, 8)));
      expect(presetRange(DatePreset.thisWeek, now, calendar),
          DateRange(DateTime(2026, 10, 5), DateTime(2026, 10, 12)));
    });

    test('month presets follow the cycle', () {
      DateRange day25(DateTime d) => fixedDayCycle(d, 25);
      expect(presetRange(DatePreset.thisMonth, now, day25),
          DateRange(DateTime(2026, 9, 25), DateTime(2026, 10, 25)));
      expect(presetRange(DatePreset.lastMonth, now, day25),
          DateRange(DateTime(2026, 8, 25), DateTime(2026, 9, 25)));
      expect(presetRange(DatePreset.last3Months, now, calendar),
          DateRange(DateTime(2026, 8, 1), DateTime(2026, 11, 1)));
    });

    test('this year and all time', () {
      expect(presetRange(DatePreset.thisYear, now, calendar),
          DateRange(DateTime(2026), DateTime(2027)));
      expect(presetRange(DatePreset.allTime, now, calendar), isNull);
    });
  });
}
