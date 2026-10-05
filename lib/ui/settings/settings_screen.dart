import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../../state/settings_store.dart';
import '../accounts/accounts_screen.dart';
import '../categories/categories_screen.dart';
import '../categories/default_categories_sheet.dart';
import '../sheets/account_sheets.dart';
import '../widgets/emoji_avatar.dart';
import '../widgets/segmented.dart';

/// One Settings page. App-wide settings first; the per-account group joins in a later milestone.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final settings = context.watch<SettingsStore>();
    final accounts = context.select<LedgerStore, int>((l) => l.accounts.length);
    final top = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(s.tabSettings, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 18),
        _GroupLabel(s.settingsAppGroup),
        _Group(children: [
          _Row(
            icon: Icons.palette_outlined,
            title: s.settingsTheme,
            below: Segmented<ThemeMode>(
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labels: [s.themeSystem, s.themeLight, s.themeDark],
              selected: settings.themeMode,
              onChanged: settings.setThemeMode,
            ),
          ),
          _Row(
            icon: Icons.account_balance_wallet_outlined,
            title: s.settingsAccounts,
            value: s.accountsCount(accounts),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AccountsScreen()),
            ),
          ),
          _Row(
            icon: Icons.info_outline_rounded,
            title: s.settingsAbout,
            subtitle: s.aboutVersion(AppInfo.version, AppInfo.buildNumber, AppInfo.buildSha),
          ),
        ]),
        const SizedBox(height: 24),
        const _AccountGroup(),
        const SizedBox(height: 16),
        Center(
          child: Text(s.appName, style: TextStyle(color: c.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Per-account settings, tinted in the account's colour so their scope is obvious.
class _AccountGroup extends StatelessWidget {
  const _AccountGroup();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final ledger = context.watch<LedgerStore>();
    final account = ledger.activeAccount;
    if (account == null) return const SizedBox.shrink();
    final color = Color(account.color);
    final cats = ledger.categoriesFor(account.id);
    final expenseDefault = ledger.category(ledger.defaultCategoryId(account.id, TxnType.expense));
    final incomeDefault = ledger.category(ledger.defaultCategoryId(account.id, TxnType.income));
    final badge = _ScopeBadge(emoji: account.emoji, color: color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(s.settingsAccountGroup(account.name)),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withValues(alpha: 0.06), c.surface),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Color.alphaBlend(color.withValues(alpha: 0.35), c.line)),
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.tinted(color),
                  border: Border(left: BorderSide(color: color, width: 5)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    EmojiAvatar(emoji: account.emoji, color: color, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            '${s.accountTypeLabel(account.type.name)} · ${account.currency}',
                            style: TextStyle(color: c.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: () => showAccountSwitcher(context),
                      child: Text(s.switchLabel),
                    ),
                  ],
                ),
              ),
              _Row(
                icon: Icons.category_outlined,
                title: s.categoriesTitle,
                subtitle: s.categoriesCount(cats.length),
                badge: badge,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
                ),
              ),
              Divider(height: 1, indent: 60, color: c.line),
              _Row(
                icon: Icons.star_outline_rounded,
                title: s.defaultCategories,
                subtitle: s.defaultSummary(expenseDefault?.name ?? '—', incomeDefault?.name ?? '—'),
                badge: badge,
                onTap: () => showDefaultCategoriesSheet(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Text(s.accountScopeHint(account.name), style: TextStyle(color: c.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Small chip that marks a row as applying to the current account only.
class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.tinted(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: context.colors.muted,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: c.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.below,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? below;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: c.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 12.5),
                      ),
                  ],
                ),
              ),
              if (badge != null) ...[badge!, const SizedBox(width: 4)],
              if (value != null)
                Text(value!, style: TextStyle(color: c.muted, fontSize: 13)),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.muted),
            ],
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
