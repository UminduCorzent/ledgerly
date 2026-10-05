import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/account.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';
import 'account_editor_sheet.dart';
import 'delete_account_flow.dart';

/// Manage accounts: grouped by type; reorder mode flattens into a draggable list.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<String>? _order; // non-null while reordering

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final store = context.watch<LedgerStore>();
    final accounts = store.accounts;
    final reordering = _order != null;

    return Scaffold(
      appBar: AppTopBar(
        title: reordering ? s.reorder : s.settingsAccounts,
        leading: reordering
            ? IconButton(
                tooltip: s.cancel,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _order = null),
              )
            : null,
        actions: [
          if (reordering)
            TextButton(onPressed: _saveOrder, child: Text(s.save))
          else ...[
            if (accounts.length > 1)
              IconButton(
                tooltip: s.reorder,
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: () => setState(() => _order = accounts.map((a) => a.id).toList()),
              ),
            IconButton(
              tooltip: s.addAccount,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => showAccountEditor(context),
            ),
          ],
        ],
      ),
      body: reordering ? _buildReorder(store) : _buildGrouped(store, accounts),
    );
  }

  Widget _buildGrouped(LedgerStore store, List<Account> accounts) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final children = <Widget>[];
    for (final type in AccountType.values) {
      final group = accounts.where((a) => a.type == type).toList();
      if (group.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Text(
          s.accountTypeLabel(type.name).toUpperCase(),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.muted),
        ),
      ));
      for (final a in group) {
        children.add(Padding(
          key: ValueKey(a.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: _AccountCard(
            account: a,
            active: a.id == store.activeAccount?.id,
            balance: store.balanceOf(a.id),
            canDelete: accounts.length > 1,
            onTap: () async {
              if (a.id == store.activeAccount?.id) return;
              await store.setActive(a.id);
              if (mounted) showSnack(context, s.switchedTo('${a.emoji} ${a.name}'));
            },
            onEdit: () => showAccountEditor(context, editing: a),
            onDelete: () => runDeleteAccountFlow(context, a),
          ),
        ));
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: children);
  }

  Widget _buildReorder(LedgerStore store) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final order = _order!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Icon(Icons.drag_indicator_rounded, size: 18, color: c.muted),
              const SizedBox(width: 6),
              Text(s.reorderHint, style: TextStyle(color: c.muted)),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            buildDefaultDragHandles: false,
            itemCount: order.length,
            // onReorderItem already adjusts `to` for the removed item.
            onReorderItem: (from, to) {
              setState(() {
                final id = order.removeAt(from);
                order.insert(to, id);
              });
            },
            itemBuilder: (context, i) {
              final a = store.account(order[i])!;
              return Padding(
                key: ValueKey(a.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: _AccountCard(
                  account: a,
                  active: a.id == store.activeAccount?.id,
                  balance: store.balanceOf(a.id),
                  canDelete: false,
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle_rounded, color: c.muted),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveOrder() async {
    final order = _order;
    if (order == null) return;
    final s = AppStrings.of(context);
    final r = await context.read<LedgerStore>().reorderAccounts(order);
    if (!mounted || !r.success) return;
    HapticFeedback.lightImpact();
    setState(() => _order = null);
    showSnack(context, s.accountsReordered);
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.active,
    required this.balance,
    required this.canDelete,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.trailing,
  });

  final Account account;
  final bool active;
  final double balance;
  final bool canDelete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    final color = Color(account.color);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: active ? color : c.line, width: active ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              EmojiAvatar(emoji: account.emoji, color: color, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.tinted(color),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              s.activeAccount,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.accountTypeLabel(account.type.name)} · ${account.currency}',
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(balance, account.currency, whole: true),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              trailing ??
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: c.muted),
                    onSelected: (v) {
                      if (v == 'edit') {
                        onEdit?.call();
                      } else {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(s.edit)),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(s.delete, style: TextStyle(color: c.expense)),
                        ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
