import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/domain/date_range.dart';
import 'package:ledgerly/domain/month_cycle.dart';
import 'package:ledgerly/domain/pin_hasher.dart';
import 'package:ledgerly/models/txn.dart';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // Published test vectors (password "password", salt "salt", 32-byte key).
    test('known vectors', () {
      final p = utf8.encode('password');
      final salt = utf8.encode('salt');
      expect(_hex(pbkdf2Sha256(p, salt, 1)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(_hex(pbkdf2Sha256(p, salt, 2)),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
      expect(_hex(pbkdf2Sha256(p, salt, 4096)),
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('hash/verify round trip; iterations travel with the hash', () {
      final h = hashPin('1234', iterations: 1000, random: Random(7));
      expect(h.startsWith(r'pbkdf2$1000$'), isTrue);
      expect(verifyPin('1234', h), isTrue);
      expect(verifyPin('1235', h), isFalse);
      expect(verifyPin('1234', 'garbage'), isFalse);
    });

    test('lockout tiers', () {
      expect(lockoutFor(4), isNull);
      expect(lockoutFor(5), const Duration(seconds: 30));
      expect(lockoutFor(7), const Duration(seconds: 30));
      expect(lockoutFor(8), const Duration(minutes: 2));
      expect(lockoutFor(10), const Duration(minutes: 5));
      expect(lockoutFor(25), const Duration(minutes: 5));
    });
  });

  group('payday cycles', () {
    test('cooldown merges a bonus into the same cycle', () {
      final anchors = anchorsFrom([
        DateTime(2026, 8, 25, 9),
        DateTime(2026, 8, 30), // bonus 5 days later → ignored (cooldown 20)
        DateTime(2026, 9, 23),
        DateTime(2026, 10, 24),
      ], 20);
      expect(anchors, [DateTime(2026, 8, 25), DateTime(2026, 9, 23), DateTime(2026, 10, 24)]);
    });

    test('cycle between paydays, and an open latest cycle', () {
      final anchors = [DateTime(2026, 8, 25), DateTime(2026, 9, 23)];
      expect(anchoredCycle(DateTime(2026, 9, 1), anchors, fallbackStartDay: 1),
          DateRange(DateTime(2026, 8, 25), DateTime(2026, 9, 23)));
      final open = anchoredCycle(DateTime(2026, 10, 30), anchors, fallbackStartDay: 1);
      expect(open.start, DateTime(2026, 9, 23));
      expect(open.isOpen, isTrue);
    });

    test('before the first payday uses the fallback, cut at the payday', () {
      final anchors = [DateTime(2026, 8, 20)];
      expect(anchoredCycle(DateTime(2026, 8, 5), anchors, fallbackStartDay: 1),
          DateRange(DateTime(2026, 8, 1), DateTime(2026, 8, 20)));
      expect(anchoredCycle(DateTime(2026, 7, 5), anchors, fallbackStartDay: 1),
          DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)));
    });

    test('no anchors behaves like fixed day', () {
      expect(anchoredCycle(DateTime(2026, 10, 5), const [], fallbackStartDay: 25),
          fixedDayCycle(DateTime(2026, 10, 5), 25));
    });

    test('typical length is the median gap', () {
      expect(typicalCycleLength([DateTime(2026, 1, 1)]), 30);
      expect(
        typicalCycleLength([DateTime(2026, 1, 25), DateTime(2026, 2, 24), DateTime(2026, 3, 27)]),
        31, // gaps 30 and 31 → mean of the middle two, rounded
      );
    });

    test('incoming transfers qualify as payday regardless of categories', () {
      final cfg = const CycleConfig().copyWith(
        mode: CycleMode.payday,
        anchorCategoryIds: {'salary'},
        minAmount: 1000,
      );
      final d = DateTime(2026, 9, 24);
      Txn t(TxnType type, double amount, {String? cat, TransferDirection? dir, bool excluded = false}) => Txn(
            id: 'x',
            accountId: 'a',
            type: type,
            amount: amount,
            categoryId: cat,
            description: 'x',
            date: d,
            createdAt: d,
            direction: dir,
            excluded: excluded,
          );
      expect(qualifiesAsPayday(t(TxnType.transfer, 160000, dir: TransferDirection.incoming), cfg), isTrue);
      expect(qualifiesAsPayday(t(TxnType.transfer, 160000, dir: TransferDirection.outgoing), cfg), isFalse);
      expect(qualifiesAsPayday(t(TxnType.transfer, 500, dir: TransferDirection.incoming), cfg), isFalse);
      expect(qualifiesAsPayday(t(TxnType.income, 5000, cat: 'salary'), cfg), isTrue);
      expect(qualifiesAsPayday(t(TxnType.income, 5000, cat: 'gift'), cfg), isFalse);
      expect(qualifiesAsPayday(t(TxnType.income, 5000, cat: 'salary', excluded: true), cfg), isFalse);
      expect(qualifiesAsPayday(t(TxnType.expense, 5000, cat: 'salary'), cfg), isFalse);
    });

    test('config round trip and clamping', () {
      final cfg = const CycleConfig().copyWith(
        mode: CycleMode.payday,
        startDay: 40,
        cooldownDays: 0,
        anchorCategoryIds: {'salary'},
        minAmount: 1000,
        pinnedStart: DateTime(2026, 9, 20),
      );
      expect(cfg.startDay, 31);
      expect(cfg.cooldownDays, 1);
      final back = CycleConfig.fromMap(cfg.toMap());
      expect(back.mode, CycleMode.payday);
      expect(back.anchorCategoryIds, {'salary'});
      expect(back.minAmount, 1000);
      expect(back.pinnedStart, DateTime(2026, 9, 20));
      expect(CycleConfig.fromMap(null).isCalendar, isTrue);
    });
  });
}
