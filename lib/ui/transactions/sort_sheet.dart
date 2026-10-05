import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/txn_query.dart';
import '../../state/ledger_store.dart';
import '../../state/txn_filter_store.dart';

/// Sort options; tapping one applies it (and remembers it) immediately.
Future<void> showSortSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final s = AppStrings.of(ctx);
      final c = ctx.colors;
      final store = ctx.read<TxnFilterStore>();
      final multi = ctx.read<LedgerStore>().accounts.length > 1;
      final options = [
        for (final o in TxnSort.values)
          if (multi || (o != TxnSort.accountAsc && o != TxnSort.accountDesc)) o,
      ];
      IconData icon(TxnSort o) => switch (o) {
            TxnSort.dateDesc || TxnSort.dateAsc => Icons.event_rounded,
            TxnSort.amountDesc || TxnSort.amountAsc => Icons.payments_outlined,
            TxnSort.categoryAsc || TxnSort.categoryDesc => Icons.category_outlined,
            TxnSort.typeAsc || TxnSort.typeDesc => Icons.swap_vert_rounded,
            TxnSort.accountAsc || TxnSort.accountDesc => Icons.account_balance_wallet_outlined,
          };
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(s.sortTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    for (final o in options)
                      ListTile(
                        key: ValueKey(o),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        selected: o == store.sort,
                        selectedTileColor: c.surface2,
                        selectedColor: c.text,
                        leading: Icon(icon(o)),
                        title: Text(s.sortLabel(o.name), style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: o == store.sort ? Icon(Icons.check_rounded, color: c.primary) : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          store.setSort(o);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
