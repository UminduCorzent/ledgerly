import 'package:collection/collection.dart';

import '../models/category.dart';
import '../models/txn.dart';

/// Builds the two legs of a transfer. [received] differs from [sent] only when
/// the two accounts use different currencies.
List<Txn> buildTransferLegs({
  required String transferId,
  required String outId,
  required String inId,
  required String fromAccountId,
  required String toAccountId,
  required double sent,
  required double received,
  required DateTime date,
  required String description,
  String? notes,
  required DateTime createdAt,
  DateTime? updatedAt,
}) {
  assert(fromAccountId != toAccountId);
  return [
    Txn(
      id: outId,
      accountId: fromAccountId,
      type: TxnType.transfer,
      amount: sent,
      description: description,
      date: date,
      notes: notes,
      transferId: transferId,
      direction: TransferDirection.outgoing,
      counterAccountId: toAccountId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
    Txn(
      id: inId,
      accountId: toAccountId,
      type: TxnType.transfer,
      amount: received,
      description: description,
      date: date,
      notes: notes,
      transferId: transferId,
      direction: TransferDirection.incoming,
      counterAccountId: fromAccountId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  ];
}

/// What deleting an account changes. Applied as one write so Undo restores all of it.
class AccountDeletionPlan {
  final List<Txn> putTxns = [];
  final Set<String> deleteTxnIds = {};
  final List<Category> putCategories = [];
}

/// Labels the plan needs; passed in so this file stays free of UI strings.
class DeletionLabels {
  const DeletionLabels({
    required this.transfersCategoryName,
    required this.transferFrom,
    required this.transferTo,
  });

  final String transfersCategoryName;
  final String Function(String accountName) transferFrom;
  final String Function(String accountName) transferTo;
}

const String kTransfersCategoryEmoji = '🔁';
const int kTransfersCategoryColor = 0xFF8B5CF6;

/// Plans deleting [accountId].
///
/// Categories are shared by all accounts, so they are never deleted here.
/// * [reassignToId] null → the account's own rows are deleted. The other side
///   of each of its transfers becomes a plain income/expense row (in the shared
///   "Transfers" category, created when missing) so the surviving account's
///   balance does not change.
/// * [reassignToId] set → rows move to that account with their categories. A
///   transfer whose other side is already in the target would become a transfer
///   to itself, so both legs are removed (net zero).
AccountDeletionPlan planAccountDeletion({
  required String accountId,
  required String accountName,
  required List<Txn> txns,
  required List<Category> categories,
  String? reassignToId,
  required String Function() newId,
  required DateTime now,
  required DeletionLabels labels,
}) {
  final plan = AccountDeletionPlan();
  final cats = List<Category>.of(categories);

  Category ensureCategory(String name, String emoji, int color) {
    final lower = name.toLowerCase();
    final existing = cats.firstWhereOrNull((c) => c.name.toLowerCase() == lower);
    if (existing != null) return existing;
    final maxOrder = cats.fold<int>(-1, (m, c) => c.sortOrder > m ? c.sortOrder : m);
    final created = Category(
      id: newId(),
      name: name,
      emoji: emoji,
      color: color,
      sortOrder: maxOrder + 1,
      createdAt: now,
    );
    cats.add(created);
    plan.putCategories.add(created);
    return created;
  }

  final byTransfer = <String, List<Txn>>{};
  for (final t in txns) {
    final tid = t.transferId;
    if (tid != null) (byTransfer[tid] ??= []).add(t);
  }

  for (final t in txns.where((t) => t.accountId == accountId)) {
    if (!t.isTransfer) {
      if (reassignToId == null) {
        plan.deleteTxnIds.add(t.id);
      } else {
        plan.putTxns.add(t.copyWith(accountId: reassignToId, updatedAt: now));
      }
      continue;
    }

    final other = (byTransfer[t.transferId] ?? const <Txn>[])
        .firstWhereOrNull((o) => o.id != t.id);

    if (reassignToId == null) {
      plan.deleteTxnIds.add(t.id);
      if (other != null && other.accountId != accountId) {
        final cat = ensureCategory(
          labels.transfersCategoryName,
          kTransfersCategoryEmoji,
          kTransfersCategoryColor,
        );
        final incoming = other.direction == TransferDirection.incoming;
        plan.putTxns.add(other.copyWith(
          type: incoming ? TxnType.income : TxnType.expense,
          categoryId: cat.id,
          description: incoming
              ? labels.transferFrom(accountName)
              : labels.transferTo(accountName),
          excluded: false,
          transferId: null,
          direction: null,
          counterAccountId: null,
          updatedAt: now,
        ));
      }
    } else {
      if (other != null && other.accountId == reassignToId) {
        plan.deleteTxnIds
          ..add(t.id)
          ..add(other.id);
      } else {
        plan.putTxns.add(t.copyWith(accountId: reassignToId, updatedAt: now));
        if (other != null) {
          plan.putTxns.add(
            other.copyWith(counterAccountId: reassignToId, updatedAt: now),
          );
        }
      }
    }
  }

  return plan;
}
