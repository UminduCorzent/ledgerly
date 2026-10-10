import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/format/money.dart';
import 'package:ledgerly/domain/amount_input.dart';
import 'package:ledgerly/domain/date_range.dart';
import 'package:ledgerly/domain/ledger_math.dart';
import 'package:ledgerly/domain/month_cycle.dart';
import 'package:ledgerly/domain/transfer_rules.dart';
import 'package:ledgerly/models/category.dart';
import 'package:ledgerly/models/txn.dart';

final _t0 = DateTime(2026, 10, 1);

Txn _txn(
  String id,
  TxnType type,
  double amount, {
  String account = 'a',
  String? cat,
  DateTime? date,
  bool excluded = false,
}) =>
    Txn(
      id: id,
      accountId: account,
      type: type,
      amount: amount,
      categoryId: cat,
      description: id,
      date: date ?? _t0,
      createdAt: _t0,
      excluded: excluded,
    );

Category _cat(String id, String account, String name) => Category(
      id: id,
      accountId: account,
      name: name,
      emoji: '📌',
      color: 0xFF000000,
      sortOrder: 0,
      createdAt: _t0,
    );

void main() {
  group('money formatting', () {
    test('fixed en_US grouping with symbol', () {
      expect(formatMoney(1250, 'LKR'), 'Rs 1,250.00');
      expect(formatMoney(1250.5, 'USD'), r'$ 1,250.50');
      expect(formatMoney(1250, 'JPY'), '¥ 1,250');
      expect(formatMoney(1250.75, 'LKR', whole: true), 'Rs 1,251');
    });

    test('signed amounts use a real minus sign', () {
      expect(formatSigned(80000, 'LKR'), '+ Rs 80,000.00');
      expect(formatSigned(-1250, 'LKR'), '$kMinus Rs 1,250.00');
      expect(formatSigned(0, 'LKR'), 'Rs 0.00');
    });
  });

  group('keypad input', () {
    test('digits, decimal and limits', () {
      var s = '';
      for (final k in ['1', '2', '.', '5', '0', '9']) {
        s = applyAmountKey(s, k);
      }
      expect(s, '12.50');
      expect(applyAmountKey('', '.'), '0.');
      expect(applyAmountKey('0', '7'), '7');
      expect(applyAmountKey('12.', '.'), '12.');
      expect(applyAmountKey('12', kKeyBackspace), '1');
      expect(applyAmountKey('5', '.', decimals: 0), '5');
    });

    test('display groups the integer part only', () {
      expect(displayAmount(''), '0');
      expect(displayAmount('1234567.5'), '1,234,567.5');
      expect(displayAmount('1000.'), '1,000.');
      expect(amountToInput(12.5), '12.5');
      expect(amountToInput(80000), '80000');
    });
  });

  group('totals and balance', () {
    test('excluded rows never count; transfers count as income/expense', () {
      final txns = [
        _txn('i', TxnType.income, 1000),
        _txn('e', TxnType.expense, 300),
        _txn('x', TxnType.expense, 500, excluded: true),
        Txn(
          id: 'tout',
          accountId: 'a',
          type: TxnType.transfer,
          amount: 200,
          description: 't',
          date: _t0,
          createdAt: _t0,
          direction: TransferDirection.outgoing,
          // Even if flagged, a transfer leg must still count.
          excluded: true,
        ),
      ];
      final t = totalsOf(txns);
      expect(t.income, 1000);
      expect(t.expense, 500); // 300 expense + 200 transferred out
      expect(t.transferOut, 200);
      expect(t.net, 500);
    });

    test('range filter is half-open', () {
      final r = DateRange(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
      final txns = [
        _txn('a', TxnType.income, 10, date: DateTime(2026, 9, 30, 23, 59)),
        _txn('b', TxnType.income, 20, date: DateTime(2026, 10, 1)),
        _txn('c', TxnType.income, 40, date: DateTime(2026, 11, 1)),
      ];
      expect(totalsOf(txns, r).income, 20);
    });

    test('breakdown keeps top 5 plus Other, largest first', () {
      final txns = [
        for (var i = 0; i < 7; i++) _txn('t$i', TxnType.expense, (i + 1) * 10.0, cat: 'c$i'),
        _txn('inc', TxnType.income, 999, cat: 'c0'),
      ];
      final b = breakdownOf(txns, TxnType.expense);
      expect(b.total, 280);
      expect(b.entries.length, 6);
      expect(b.entries.first.categoryId, 'c6');
      expect(b.entries.last.isOther, isTrue);
      expect(b.entries.last.amount, 30); // c0 (10) + c1 (20)
    });

    test('breakdown adds one Transfers slice per direction, never in Other', () {
      Txn leg(String id, double amount, TransferDirection dir) => Txn(
            id: id,
            accountId: 'a',
            type: TxnType.transfer,
            amount: amount,
            description: id,
            date: _t0,
            createdAt: _t0,
            direction: dir,
          );
      final txns = [
        for (var i = 0; i < 7; i++) _txn('t$i', TxnType.expense, (i + 1) * 10.0, cat: 'c$i'),
        leg('o1', 15, TransferDirection.outgoing),
        leg('o2', 20, TransferDirection.outgoing),
        leg('in', 999, TransferDirection.incoming),
      ];
      final b = breakdownOf(txns, TxnType.expense);
      expect(b.total, 315);
      expect(b.entries.length, 7); // 5 categories + Transfers + Other
      final tr = b.entries.singleWhere((e) => e.isTransfers);
      expect(tr.amount, 35);
      expect(tr.isOther, isFalse);
      // Placed by size: after c3 (40), before c2 (30).
      expect(b.entries.indexOf(tr), 4);
      expect(b.entries.last.isOther, isTrue);
      expect(b.entries.last.amount, 30); // c0 (10) + c1 (20); transfers never fold in

      final inc = breakdownOf(txns, TxnType.income);
      expect(inc.total, 999);
      expect(inc.entries.single.isTransfers, isTrue);
    });

    test('empty breakdown', () {
      expect(breakdownOf(const [], TxnType.income).entries, isEmpty);
    });
  });

  group('fixed-day month cycle', () {
    test('day 1 is the calendar month', () {
      final r = fixedDayCycle(DateTime(2026, 10, 5), 1);
      expect(r.start, DateTime(2026, 10, 1));
      expect(r.end, DateTime(2026, 11, 1));
    });

    test('a date before the start day belongs to last month', () {
      final r = fixedDayCycle(DateTime(2026, 10, 5), 25);
      expect(r.start, DateTime(2026, 9, 25));
      expect(r.end, DateTime(2026, 10, 25));
    });

    test('day 31 clamps to the end of short months', () {
      final r = fixedDayCycle(DateTime(2026, 2, 28, 12), 31);
      expect(r.start, DateTime(2026, 2, 28));
      expect(r.end, DateTime(2026, 3, 31));
    });

    test('previous cycle and year boundary', () {
      final r = fixedDayCycle(DateTime(2026, 1, 3), 25);
      expect(r.start, DateTime(2025, 12, 25));
      final p = previousFixedDayCycle(r, 25);
      expect(p.start, DateTime(2025, 11, 25));
      expect(p.end, DateTime(2025, 12, 25));
    });
  });

  group('transfers and account deletion', () {
    List<Txn> transfer() => buildTransferLegs(
          transferId: 'T',
          outId: 'out',
          inId: 'in',
          fromAccountId: 'a',
          toAccountId: 'b',
          sent: 100,
          received: 0.33,
          date: _t0,
          description: 'Move',
          createdAt: _t0,
        );

    var n = 0;
    String newId() => 'new${n++}';
    final labels = DeletionLabels(
      transfersCategoryName: 'Transfers',
      transferFrom: (a) => 'Transfer from $a',
      transferTo: (a) => 'Transfer to $a',
    );

    test('legs mirror each other', () {
      final legs = transfer();
      expect(legs[0].signedAmount, -100);
      expect(legs[1].signedAmount, 0.33);
      expect(legs[0].counterAccountId, 'b');
      expect(legs[1].counterAccountId, 'a');
    });

    test('delete mode turns the surviving leg into a plain row', () {
      final txns = [...transfer(), _txn('own', TxnType.expense, 5, account: 'a', cat: 'ca')];
      final cats = [_cat('ca', 'a', 'Food'), _cat('cb', 'b', 'Food')];
      final plan = planAccountDeletion(
        accountId: 'a',
        accountName: 'Bank',
        txns: txns,
        categories: cats,
        newId: newId,
        now: _t0,
        labels: labels,
      );
      expect(plan.deleteTxnIds, containsAll(['out', 'own']));
      expect(plan.deleteCategoryIds, {'ca'});
      final converted = plan.putTxns.single;
      expect(converted.id, 'in');
      expect(converted.type, TxnType.income);
      expect(converted.transferId, isNull);
      expect(converted.description, 'Transfer from Bank');
      expect(converted.amount, 0.33); // balance of b unchanged
      expect(plan.putCategories.single.name, 'Transfers');
      expect(plan.putCategories.single.accountId, 'b');
      expect(converted.categoryId, plan.putCategories.single.id);
    });

    test('reassign moves rows and maps categories by name', () {
      final txns = [_txn('own', TxnType.expense, 5, account: 'a', cat: 'ca')];
      final cats = [_cat('ca', 'a', 'Food'), _cat('cc', 'c', 'food')];
      final plan = planAccountDeletion(
        accountId: 'a',
        accountName: 'Bank',
        txns: txns,
        categories: cats,
        reassignToId: 'c',
        newId: newId,
        now: _t0,
        labels: labels,
      );
      final moved = plan.putTxns.single;
      expect(moved.accountId, 'c');
      expect(moved.categoryId, 'cc');
      expect(plan.putCategories, isEmpty);
    });

    test('reassigning into the counterpart account removes both legs', () {
      final plan = planAccountDeletion(
        accountId: 'a',
        accountName: 'Bank',
        txns: transfer(),
        categories: const [],
        reassignToId: 'b',
        newId: newId,
        now: _t0,
        labels: labels,
      );
      expect(plan.deleteTxnIds, {'out', 'in'});
      expect(plan.putTxns, isEmpty);
    });

    test('reassigning elsewhere keeps it a transfer', () {
      final plan = planAccountDeletion(
        accountId: 'a',
        accountName: 'Bank',
        txns: transfer(),
        categories: const [],
        reassignToId: 'c',
        newId: newId,
        now: _t0,
        labels: labels,
      );
      final out = plan.putTxns.firstWhere((t) => t.id == 'out');
      final inn = plan.putTxns.firstWhere((t) => t.id == 'in');
      expect(out.accountId, 'c');
      expect(out.isTransfer, isTrue);
      expect(inn.counterAccountId, 'c');
    });
  });

  test('txn map round trip', () {
    final legs = buildTransferLegs(
      transferId: 'T',
      outId: 'o',
      inId: 'i',
      fromAccountId: 'a',
      toAccountId: 'b',
      sent: 12.5,
      received: 12.5,
      date: DateTime(2026, 10, 5, 13, 20),
      description: 'x',
      notes: 'n',
      createdAt: _t0,
    );
    final back = Txn.fromMap(legs[0].toMap());
    expect(back.direction, TransferDirection.outgoing);
    expect(back.date, DateTime(2026, 10, 5, 13, 20));
    expect(back.notes, 'n');
    expect(back.amount, 12.5);
  });
}
