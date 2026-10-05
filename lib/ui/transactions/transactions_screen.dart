import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../add/add_txn_sheet.dart';
import '../detail/txn_detail_sheet.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';

/// Transactions tab — day-grouped history of the active account.
/// (Search, filters, sorting and multi-select come in the next milestone.)
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LedgerStore>();
    final account = store.activeAccount;
    final s = AppStrings.of(context);
    final c = context.colors;
    if (account == null) return const SizedBox.shrink();
    final items = store.dayListItems(account.id);
    final top = MediaQuery.paddingOf(context).top;

    String keyOf(Object o) => o is Txn ? o.id : 'day:${(o as DayGroup).day.toIso8601String()}';

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              s.tabTransactions,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(s.txComingSoon, style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              emoji: '🧾',
              title: s.txEmptyTitle,
              body: s.txEmptyBody,
              actionLabel: s.addTitle,
              onAction: () => showAddTxnSheet(context),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = items[i];
                  if (item is DayGroup) {
                    return _DayHeader(
                      key: ValueKey(keyOf(item)),
                      group: item,
                      currency: account.currency,
                    );
                  }
                  final t = item as Txn;
                  return TxnTile(
                    key: ValueKey(t.id),
                    txn: t,
                    onTap: () => showTxnDetail(context, t.id),
                  );
                },
                childCount: items.length,
                // Rows are keyed by id, so inserts/deletes don't rebuild everything after them.
                findChildIndexCallback: (key) {
                  if (key is! ValueKey<String>) return null;
                  final idx = items.indexWhere((o) => keyOf(o) == key.value);
                  return idx < 0 ? null : idx;
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({super.key, required this.group, required this.currency});

  final DayGroup group;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    final net = group.net;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dayLabel(group.day, s).toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: c.muted,
              ),
            ),
          ),
          Text(
            formatSigned(net, currency, whole: true),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: net >= 0 ? c.income : c.expense,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
