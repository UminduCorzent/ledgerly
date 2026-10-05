import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/tokens.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import 'common.dart';
import 'emoji_avatar.dart';

/// One transaction row. Amounts are in the row's own account currency.
class TxnTile extends StatelessWidget {
  const TxnTile({
    super.key,
    required this.txn,
    required this.onTap,
    this.onLongPress,
    this.showAccount = false,
    this.selectionMode = false,
    this.selected = false,
  });

  final Txn txn;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showAccount;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = context.read<LedgerStore>();
    final account = store.account(txn.accountId);
    final currency = account?.currency ?? kDefaultCurrency;
    final category = store.category(txn.categoryId);

    final Widget avatar;
    final String title;
    final String subtitle;
    final Color amountColor;
    if (txn.isTransfer) {
      avatar = const TransferAvatar();
      final other = store.account(txn.counterAccountId);
      final outgoing = txn.direction == TransferDirection.outgoing;
      final from = outgoing ? account?.name : other?.name;
      final to = outgoing ? other?.name : account?.name;
      title = txn.description;
      subtitle = '${from ?? '—'} → ${to ?? '—'} · ${timeLabel(txn.date)}';
      // (Transfer rows always name both accounts, so showAccount adds nothing.)
      amountColor = c.transfer;
    } else {
      avatar = EmojiAvatar(
        emoji: category?.emoji ?? '📌',
        color: Color(category?.color ?? 0xFF94A3B8),
      );
      title = txn.description;
      final parts = <String>[
        category?.name ?? '—',
        if (showAccount && account != null) account.name,
        timeLabel(txn.date),
      ];
      subtitle = parts.join(' · ');
      amountColor = txn.type == TxnType.income ? c.income : c.expense;
    }

    return Material(
      color: selected ? c.primary.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? c.primary : c.muted,
                size: 22,
              ),
              const SizedBox(width: 10),
            ],
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatSigned(txn.signedAmount, currency),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (!txn.isCounted) ...[
                  const SizedBox(height: 3),
                  const ExcludedPill(),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
