import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/domain/backup_codec.dart';
import 'package:ledgerly/domain/export_import.dart';
import 'package:ledgerly/models/txn.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  final rows = [
    ExportRow(
      date: DateTime(2026, 10, 5, 13, 20),
      type: TxnType.expense,
      account: 'Personal',
      category: 'Food',
      description: 'Lunch, with team',
      amount: 1250,
      currency: 'LKR',
      notes: 'Paid "cash"',
    ),
    ExportRow(
      date: DateTime(2026, 10, 4, 8),
      type: TxnType.transfer,
      account: 'Personal',
      category: '',
      description: 'Saving',
      amount: 20000,
      currency: 'LKR',
      direction: TransferDirection.outgoing,
      counterpart: 'Savings',
    ),
    ExportRow(
      date: DateTime(2026, 10, 4, 8),
      type: TxnType.transfer,
      account: 'Savings',
      category: '',
      description: 'Saving',
      amount: 20000,
      currency: 'LKR',
      direction: TransferDirection.incoming,
      counterpart: 'Personal',
    ),
  ];

  test('CSV export round-trips through the importer', () {
    final csv = toCsv(rows);
    final r = parseImportFile('export.csv', _bytes(csv));
    expect(r.ok, isTrue);
    expect(r.skipped, isEmpty);
    expect(r.rows.length, 3);
    final first = r.rows.first;
    expect(first.date, DateTime(2026, 10, 5, 13, 20));
    expect(first.description, 'Lunch, with team');
    expect(first.notes, 'Paid "cash"');
    expect(first.amount, 1250);
    expect(first.account, 'Personal');
    final (pairs, unpaired) = pairTransfers(r.rows.where((x) => x.type == TxnType.transfer).toList());
    expect(pairs.length, 1);
    expect(unpaired, isEmpty);
    expect(pairs.first.$1.account, 'Personal');
    expect(pairs.first.$2!.account, 'Savings');
  });

  test('Excel export round-trips through the importer', () {
    final r = parseImportFile('export.xlsx', toXlsx(rows));
    expect(r.ok, isTrue);
    expect(r.rows.length, 3);
    expect(r.rows.first.amount, 1250);
    expect(r.rows[1].direction, TransferDirection.outgoing);
  });

  test('bad rows are skipped with a reason; headers are flexible', () {
    const csv = 'date,TYPE, Amount ,category\n'
        '2026-10-01,income,500,Salary\n'
        '2026-10-02,savings,10,Other\n'
        'not a date,expense,10,Food\n'
        '2026-10-03,expense,abc,Food\n'
        '05 Oct 2026,expense,-75.5,Food\n';
    final r = parseImportFile('bank.csv', _bytes(csv));
    expect(r.rows.length, 2);
    expect(r.rows.last.amount, 75.5); // negative amounts are taken as absolute
    expect(r.skipped.map((s) => s.reason).toList(),
        [SkipReason.badType, SkipReason.badDate, SkipReason.badAmount]);
  });

  test('missing columns, empty and unsupported files', () {
    expect(parseImportFile('a.csv', _bytes('date,amount\n2026-01-01,5')).error,
        ImportError.missingColumns);
    expect(parseImportFile('a.csv', _bytes('date,type,amount\n')).error, ImportError.emptyFile);
    expect(parseImportFile('a.pdf', _bytes('x')).error, ImportError.unsupportedFormat);
    expect(parseImportFile('a.json', _bytes('{oops')).error, ImportError.unreadable);
  });

  test('JSON import accepts a bare list or {transactions: [...]}', () {
    const json = '{"transactions":[{"date":"2026-10-01","type":"Expense","amount":12.5,"category":"Food"}]}';
    final r = parseImportFile('x.json', _bytes(json));
    expect(r.rows.single.type, TxnType.expense);
    expect(r.rows.single.description, 'Food');
  });

  test('duplicate key ignores case and time of day', () {
    String k(DateTime d, String desc) => duplicateKey(
          accountKey: 'Personal',
          date: d,
          type: TxnType.expense,
          category: 'Food',
          description: desc,
          amount: 10,
        );
    expect(k(DateTime(2026, 1, 1, 9), 'Lunch'), k(DateTime(2026, 1, 1, 18), 'lunch '));
    expect(k(DateTime(2026, 1, 1), 'Lunch'), isNot(k(DateTime(2026, 1, 2), 'Lunch')));
  });

  group('backup codec', () {
    BackupData sample() => BackupData(
          createdAt: DateTime(2026, 10, 5),
          accounts: [
            {'id': 'a', 'name': 'Personal'},
          ],
          categories: [
            {'id': 'c', 'accountId': 'a', 'name': 'Food'},
          ],
          txns: [
            {'id': 't', 'accountId': 'a', 'amount': 5.0},
          ],
          settings: {'activeAccountId': 'a', 'lock_hash': 'secret', 'lock_enabled': true, 'txnSort': 'dateAsc'},
        );

    test('round trip, and lock settings never leave the device', () {
      final text = encodeBackup(sample());
      expect(text.contains('secret'), isFalse);
      expect(text.contains('lock_enabled'), isFalse);
      final back = decodeBackup(text)!;
      expect(back.accounts.single['name'], 'Personal');
      expect(back.txns.single['amount'], 5.0);
      expect(back.settings, {'activeAccountId': 'a', 'txnSort': 'dateAsc'});
      expect(back.recordCount, 3);
    });

    test('rejects files that are not Ledgerly backups', () {
      expect(decodeBackup('not json'), isNull);
      expect(decodeBackup('{"app":"other","formatVersion":1}'), isNull);
      expect(decodeBackup('{"app":"ledgerly","formatVersion":99,"accounts":[],"categories":[],"txns":[],"settings":{}}'), isNull);
      expect(decodeBackup('{"app":"ledgerly","formatVersion":1,"accounts":[],"categories":[],"txns":[],"settings":{}}'), isNull);
    });
  });
}
