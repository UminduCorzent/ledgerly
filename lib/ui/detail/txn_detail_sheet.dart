import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../add/add_txn_sheet.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';

/// Read-only details with Edit / Delete. [context] must outlive the sheet
/// (it is used to open the Edit sheet after this one closes).
Future<void> showTxnDetail(BuildContext context, String txnId) async {
  final action = await showModalBottomSheet<_DetailAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TxnDetailSheet(txnId: txnId),
  );
  if (!context.mounted || action == null) return;
  final store = context.read<LedgerStore>();
  final txn = store.txn(txnId);
  if (txn == null) return;
  final s = AppStrings.of(context);
  switch (action) {
    case _DetailAction.edit:
      await showAddTxnSheet(context, editing: txn);
    case _DetailAction.delete:
      final r = await store.deleteTxn(txnId);
      if (!context.mounted || !r.success) return;
      HapticFeedback.mediumImpact();
      final undo = r.undo;
      showSnack(
        context,
        s.transactionDeleted,
        onUndo: undo == null ? null : () => store.undo(undo),
      );
  }
}

enum _DetailAction { edit, delete }

class _TxnDetailSheet extends StatelessWidget {
  const _TxnDetailSheet({required this.txnId});

  final String txnId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LedgerStore>();
    final t = store.txn(txnId);
    if (t == null) return const SizedBox(height: 120);
    final s = AppStrings.of(context);
    final c = context.colors;
    final account = store.account(t.accountId);
    final currency = account?.currency ?? kDefaultCurrency;
    final category = store.category(t.categoryId);

    final Color amountColor = switch (t.type) {
      TxnType.income => c.income,
      TxnType.expense => c.expense,
      TxnType.transfer => c.transfer,
    };

    final rows = <(String, String)>[];
    if (t.isTransfer) {
      final other = store.counterpart(t);
      final outLeg = t.direction == TransferDirection.outgoing ? t : other;
      final inLeg = t.direction == TransferDirection.outgoing ? other : t;
      final from = store.account(outLeg?.accountId);
      final to = store.account(inLeg?.accountId ?? t.counterAccountId);
      if (from != null && outLeg != null) {
        rows.add((s.detailFrom, '${from.emoji} ${from.name} · ${formatMoney(outLeg.amount, from.currency)}'));
      }
      if (to != null) {
        final amt = inLeg?.amount ?? t.amount;
        rows.add((s.detailTo, '${to.emoji} ${to.name} · ${formatMoney(amt, to.currency)}'));
      }
    } else {
      rows.add((s.detailCategory, '${category?.emoji ?? '📌'} ${category?.name ?? '—'}'));
      if (account != null) rows.add((s.detailAccount, '${account.emoji} ${account.name}'));
    }
    rows.add((s.detailDescription, t.description));
    rows.add((s.detailDate, fullDateTime(t.date)));
    if ((t.notes ?? '').isNotEmpty) rows.add((s.detailNotes, t.notes!));
    if (!t.isCounted) rows.add((s.detailCounting, s.detailExcludedValue));
    rows.add((s.detailCreated, fullDateTime(t.createdAt)));
    if (t.updatedAt != null) rows.add((s.detailUpdated, fullDateTime(t.updatedAt!)));

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: [
                    if (t.isTransfer)
                      const TransferAvatar(size: 56)
                    else
                      EmojiAvatar(
                        emoji: category?.emoji ?? '📌',
                        color: Color(category?.color ?? 0xFF94A3B8),
                        size: 56,
                      ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatSigned(t.signedAmount, currency),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.tinted(amountColor),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.typeLabel(t.type.name).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: amountColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final (label, value) in rows)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(label, style: TextStyle(color: c.muted)),
                            ),
                            Expanded(
                              child: Text(
                                value,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.expense,
                        side: BorderSide(color: c.expense, width: 1.5),
                      ),
                      onPressed: () async {
                        final ok = await confirmDestructive(
                          context,
                          title: s.deleteTxnTitle,
                          body: t.isTransfer ? s.deleteTransferBody : s.deleteTxnBody,
                        );
                        if (ok && context.mounted) Navigator.pop(context, _DetailAction.delete);
                      },
                      child: Text(s.delete),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context, _DetailAction.edit);
                      },
                      child: Text(s.edit),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
