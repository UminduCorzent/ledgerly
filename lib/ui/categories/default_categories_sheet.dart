import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../sheets/category_picker.dart';
import '../widgets/emoji_avatar.dart';

/// Which category the Add sheet preselects for Expense and Income (per account).
Future<void> showDefaultCategoriesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _DefaultCategoriesSheet(),
  );
}

class _DefaultCategoriesSheet extends StatelessWidget {
  const _DefaultCategoriesSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final ledger = context.watch<LedgerStore>();
    final account = ledger.activeAccount;
    if (account == null) return const SizedBox.shrink();

    Widget row(TxnType type, String label, Color accent) {
      final cat = ledger.category(ledger.defaultCategoryId(account.id, type));
      return Material(
        color: c.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final id = await showCategoryPicker(context, accountId: account.id, selectedId: cat?.id);
            if (id == null) return;
            HapticFeedback.selectionClick();
            await ledger.setDefaultCategory(account.id, type, id);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(width: 4, height: 34, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (cat != null) ...[
                  EmojiAvatar(emoji: cat.emoji, color: Color(cat.color), size: 30),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.defaultCategories, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(s.defaultCategoriesBody, style: TextStyle(color: c.muted)),
            const SizedBox(height: 16),
            row(TxnType.expense, s.defaultExpense, c.expense),
            const SizedBox(height: 8),
            row(TxnType.income, s.defaultIncome, c.income),
          ],
        ),
      ),
    );
  }
}
