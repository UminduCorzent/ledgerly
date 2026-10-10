import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../domain/ledger_math.dart';
import '../../domain/transfer_rules.dart';
import '../../models/account.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../../state/txn_filter_store.dart';
import '../add/add_txn_sheet.dart';
import '../detail/txn_detail_sheet.dart';
import '../sheets/account_sheets.dart';
import '../shell/app_shell.dart';
import '../widgets/common.dart';
import '../widgets/donut_chart.dart';
import '../widgets/emoji_avatar.dart';
import '../widgets/segmented.dart';
import '../widgets/txn_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _allTime = false;
  TxnType _breakdownType = TxnType.expense;
  String? _highlighted;

  /// Opens the Transactions tab filtered to what was tapped, for the period shown here.
  void _openList(
    BuildContext context, {
    required TxnType type,
    String? categoryName,
    bool transfersOnly = false,
  }) {
    context.read<TxnFilterStore>().openFromHome(
          type: type,
          categoryName: categoryName,
          transfersOnly: transfersOnly,
          allTime: _allTime,
        );
    ShellNav.maybeOf(context)?.goTo(AppShell.transactions);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LedgerStore>();
    final account = store.activeAccount;
    if (account == null) return const SizedBox.shrink();
    final s = AppStrings.of(context);
    final now = DateTime.now();
    final hasTxns = store.txnCount(account.id) > 0;
    final top = MediaQuery.paddingOf(context).top;

    final children = <Widget>[
      _HomeHeader(account: account),
      const SizedBox(height: 14),
    ];

    if (!hasTxns) {
      children.add(SectionCard(
        child: EmptyState(
          emoji: '🧾',
          title: s.homeEmptyTitle,
          body: s.homeEmptyBody,
          actionLabel: s.homeEmptyAction,
          onAction: () => showAddTxnSheet(context),
        ),
      ));
    } else {
      final summary = store.summary(account.id, allTime: _allTime, now: now);
      children.addAll([
        _HeroCard(
          label: summary.range == null
              ? s.balanceAllTime
              : s.balanceForRange(rangeLabel(summary.range!, s)),
          balance: summary.balance,
          currency: account.currency,
          income: summary.totals.income,
          expense: summary.totals.expense,
          allTime: _allTime,
          onPeriod: (all) => setState(() {
            _allTime = all;
            _highlighted = null;
          }),
          onStatTap: (type) => _openList(context, type: type),
        ),
        if (!_allTime && store.cycleRunningLongDay(account.id, now) != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _RunningLongChip(day: store.cycleRunningLongDay(account.id, now)!),
          ),
        if (store.accounts.length > 1) ...[
          const SizedBox(height: 20),
          SectionHeader(title: s.accountsTitle),
          const _AccountsStrip(),
        ],
        const SizedBox(height: 20),
        _BreakdownCard(
          account: account,
          breakdown: store.breakdown(account.id, _breakdownType, allTime: _allTime, now: now),
          type: _breakdownType,
          highlighted: _highlighted,
          onType: (t) => setState(() {
            _breakdownType = t;
            _highlighted = null;
          }),
          onHighlight: (id) => setState(() => _highlighted = id == _highlighted ? null : id),
          onOpenCategory: (name) => _openList(context, type: _breakdownType, categoryName: name),
          onOpenTransfers: () => _openList(context, type: _breakdownType, transfersOnly: true),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: s.recentTitle,
          action: s.seeAll,
          onAction: () => ShellNav.maybeOf(context)?.goTo(AppShell.transactions),
        ),
        SectionCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              for (final t in store.txnsFor(account.id).take(5))
                TxnTile(
                  key: ValueKey(t.id),
                  txn: t,
                  onTap: () => showTxnDetail(context, t.id),
                ),
            ],
          ),
        ),
      ]);
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 120),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    return Row(
      children: [
        Flexible(
          child: Semantics(
            button: true,
            label: s.switchAccount,
            child: Material(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.line)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => showAccountSwitcher(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmojiAvatar(emoji: account.emoji, color: Color(account.color), size: 32),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.expand_more_rounded, color: c.muted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.balance,
    required this.currency,
    required this.income,
    required this.expense,
    required this.allTime,
    required this.onPeriod,
    required this.onStatTap,
  });

  final String label;
  final double balance;
  final String currency;
  final double income;
  final double expense;
  final bool allTime;
  final ValueChanged<bool> onPeriod;
  final ValueChanged<TxnType> onStatTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    final cur = currencyOf(currency);
    // White text on the brand gradient reads well in both themes.
    const onHero = Colors.white;
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.heroA, c.heroB],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: onHero.withValues(alpha: 0.92), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Segmented<bool>(
                  values: const [false, true],
                  labels: [s.periodMonth, s.periodAll],
                  selected: allTime,
                  onChanged: onPeriod,
                  compact: true,
                  onGradient: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: balance, end: balance),
              duration: Motion.of(context, Motion.emphasis),
              curve: Motion.enter,
              builder: (context, v, _) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${v < 0 ? '$kMinus ' : ''}${cur.code}  ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onHero.withValues(alpha: 0.85)),
                    ),
                    TextSpan(
                      text: formatMoney(v.abs(), currency, showSymbol: false),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                    ),
                  ]),
                  style: const TextStyle(color: onHero, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.arrow_upward_rounded,
                    label: s.statIncome,
                    value: formatMoney(income, currency, whole: true),
                    onTap: () => onStatTap(TxnType.income),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    icon: Icons.arrow_downward_rounded,
                    label: s.statExpense,
                    value: formatMoney(expense, currency, whole: true),
                    onTap: () => onStatTap(TxnType.expense),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const onHero = Colors.white;
    return Material(
      color: onHero.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: onHero, size: 14),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(color: onHero.withValues(alpha: 0.9), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: onHero,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountsStrip extends StatelessWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LedgerStore>();
    final s = AppStrings.of(context);
    final c = context.colors;
    final accounts = store.accounts;
    final activeId = store.activeAccount?.id;
    final totals = store.totalsByCurrency();

    Widget tile({required Widget child, bool active = false, VoidCallback? onTap, bool muted = false}) {
      return SizedBox(
        width: 136,
        child: Material(
          color: muted ? c.surface2 : c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: active ? c.primary : c.line, width: active ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ),
      );
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: accounts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == accounts.length) {
            return tile(
              muted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiAvatar(emoji: 'Σ', color: c.muted, size: 28),
                  const SizedBox(height: 6),
                  Text(s.totalLabel, style: TextStyle(color: c.muted, fontSize: 12.5)),
                  for (final e in totals.entries.take(2))
                    Text(
                      formatMoney(e.value, e.key, whole: true),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                ],
              ),
            );
          }
          final a = accounts[i];
          return tile(
            active: a.id == activeId,
            onTap: () async {
              if (a.id == activeId) return;
              await store.setActive(a.id);
              if (context.mounted) showSnack(context, s.switchedTo('${a.emoji} ${a.name}'));
            },
            child: Column(
              key: ValueKey(a.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiAvatar(emoji: a.emoji, color: Color(a.color), size: 28),
                const SizedBox(height: 6),
                Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(store.balanceOf(a.id), a.currency, whole: true),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.account,
    required this.breakdown,
    required this.type,
    required this.highlighted,
    required this.onType,
    required this.onHighlight,
    required this.onOpenCategory,
    required this.onOpenTransfers,
  });

  final Account account;
  final Breakdown breakdown;
  final TxnType type;
  final String? highlighted;
  final ValueChanged<TxnType> onType;
  final ValueChanged<String> onHighlight;
  final ValueChanged<String> onOpenCategory;
  final VoidCallback onOpenTransfers;

  static const String otherId = '__other';
  static const String transfersId = '__transfers';

  static String idOf(BreakdownEntry e) =>
      e.isTransfers ? transfersId : (e.categoryId ?? otherId);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final store = context.read<LedgerStore>();

    (String, String, Color) meta(BreakdownEntry e) {
      if (e.isOther) return ('⋯', s.otherSlice, c.muted);
      if (e.isTransfers) return (kTransfersCategoryEmoji, s.transfersCategory, c.transfer);
      final cat = store.category(e.categoryId);
      return (cat?.emoji ?? '📌', cat?.name ?? '—', Color(cat?.color ?? 0xFF94A3B8));
    }

    final entries = breakdown.entries;
    BreakdownEntry? hl;
    for (final e in entries) {
      if (idOf(e) == highlighted) hl = e;
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.breakdownTitle, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Segmented<TxnType>(
            values: const [TxnType.expense, TxnType.income],
            labels: [s.breakdownSpending, s.breakdownIncome],
            selected: type,
            onChanged: onType,
          ),
          if (breakdown.total <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                type == TxnType.expense ? s.noSpendingInPeriod : s.noIncomeInPeriod,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            Center(
              child: DonutChart(
                slices: [
                  for (final e in entries)
                    DonutSlice(idOf(e), e.amount, meta(e).$3),
                ],
                trackColor: c.surface2,
                highlighted: highlighted,
                onTapSlice: (id) {
                  if (id != null) onHighlight(id);
                },
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hl == null
                          ? (type == TxnType.expense ? s.spentLabel : s.earnedLabel)
                          : meta(hl).$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatMoney(hl?.amount ?? breakdown.total, account.currency, whole: true),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final e in entries)
              _RankRow(
                key: ValueKey(idOf(e)),
                emoji: meta(e).$1,
                name: meta(e).$2,
                color: meta(e).$3,
                amount: formatMoney(e.amount, account.currency, whole: true),
                percent: (e.amount / breakdown.total * 100).round(),
                fraction: breakdown.largest <= 0 ? 0 : e.amount / breakdown.largest,
                dimmed: highlighted != null && highlighted != idOf(e),
                onTap: () => onHighlight(idOf(e)),
                onOpen: e.isOther
                    ? null
                    : e.isTransfers
                        ? onOpenTransfers
                        : () => onOpenCategory(meta(e).$2),
                openLabel: e.isTransfers ? s.seeTransfers : s.seeCategoryTransactions(meta(e).$2),
              ),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    super.key,
    required this.emoji,
    required this.name,
    required this.color,
    required this.amount,
    required this.percent,
    required this.fraction,
    required this.dimmed,
    required this.onTap,
    required this.onOpen,
    required this.openLabel,
  });

  final String emoji;
  final String name;
  final Color color;
  final String amount;
  final int percent;
  final double fraction;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback? onOpen;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedOpacity(
      duration: Motion.of(context, Motion.micro),
      opacity: dimmed ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(
            children: [
              EmojiAvatar(emoji: emoji, color: color, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: c.surface2),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fraction.clamp(0.0, 1.0),
                              child: ColoredBox(color: color),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text('$percent%', style: TextStyle(color: c.muted, fontSize: 11.5)),
                ],
              ),
              SizedBox(
                width: 36,
                child: onOpen == null
                    ? null
                    : IconButton(
                        tooltip: openLabel,
                        visualDensity: VisualDensity.compact,
                        onPressed: onOpen,
                        icon: Icon(Icons.chevron_right_rounded, color: c.muted),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Warning chip when a payday cycle has run past its usual length.
class _RunningLongChip extends StatelessWidget {
  const _RunningLongChip({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: s.runningLongBody,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: c.warn),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.runningLong(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.warn, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
