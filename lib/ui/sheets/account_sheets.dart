import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/account.dart';
import '../../state/ledger_store.dart';
import '../accounts/accounts_screen.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';

/// Lets the user pick an account; resolves to its id (or null if dismissed).
Future<String?> showAccountPicker(
  BuildContext context, {
  required String title,
  String? selectedId,
  String? excludeId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final store = ctx.read<LedgerStore>();
      final list = store.accounts.where((a) => a.id != excludeId).toList();
      return _AccountList(
        title: title,
        accounts: list,
        selectedId: selectedId,
        onTap: (a) => Navigator.pop(ctx, a.id),
      );
    },
  );
}

/// The account switcher (Home header, Settings) with a link to Manage accounts.
Future<void> showAccountSwitcher(BuildContext context) async {
  final s = AppStrings.of(context);
  final store = context.read<LedgerStore>();
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AccountList(
      title: s.switchAccount,
      accounts: store.accounts,
      selectedId: store.activeAccount?.id,
      onTap: (a) => Navigator.pop(ctx, a.id),
      footer: OutlinedButton.icon(
        onPressed: () => Navigator.pop(ctx, const _Manage()),
        icon: const Icon(Icons.tune_rounded),
        label: Text(s.manageAccounts),
      ),
    ),
  );
  if (!context.mounted || picked == null) return;
  if (picked is _Manage) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountsScreen()));
    return;
  }
  final id = picked as String;
  if (id == store.activeAccount?.id) return;
  await store.setActive(id);
  if (!context.mounted) return;
  final a = store.account(id);
  if (a != null) showSnack(context, s.switchedTo('${a.emoji} ${a.name}'));
}

class _Manage {
  const _Manage();
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.title,
    required this.accounts,
    required this.onTap,
    this.selectedId,
    this.footer,
  });

  final String title;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<Account> onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    final store = context.read<LedgerStore>();
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: accounts.length,
                itemBuilder: (context, i) {
                  final a = accounts[i];
                  final selected = a.id == selectedId;
                  return Material(
                    key: ValueKey(a.id),
                    color: selected ? c.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onTap(a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            EmojiAvatar(emoji: a.emoji, color: Color(a.color)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  Text(
                                    '${s.accountTypeLabel(a.type.name)} · ${a.currency}',
                                    style: TextStyle(color: c.muted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatMoney(store.balanceOf(a.id), a.currency, whole: true),
                              style: TextStyle(
                                color: c.muted,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_rounded, color: c.primary),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: footer),
          ],
        ),
      ),
    );
  }
}
