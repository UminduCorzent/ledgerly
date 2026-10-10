import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/date_range.dart';
import '../../domain/txn_query.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../../state/txn_filter_store.dart';
import '../add/add_txn_sheet.dart';
import '../detail/txn_detail_sheet.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'filter_sheet.dart';
import 'sort_sheet.dart';

/// Transactions tab: search, month navigator, filters, sort, day groups with
/// sticky headers, swipe-to-delete and multi-select.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _searching = false;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  /// Non-empty = selection mode.
  final Set<String> _selected = {};

  /// Rows hidden right after a swipe, until the delete lands in the store.
  final Set<String> _pendingRemoval = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) context.read<TxnFilterStore>().setQuery(v);
    });
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _search.text = context.read<TxnFilterStore>().query;
      _searchFocus.requestFocus();
    } else {
      _debounce?.cancel();
      _search.clear();
      context.read<TxnFilterStore>().setQuery('');
    }
  }

  void _toggleSelected(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _startSelection(String id) {
    HapticFeedback.mediumImpact();
    setState(() => _selected.add(id));
  }

  Future<void> _swipeDelete(Txn t) async {
    final s = AppStrings.of(context);
    final store = context.read<LedgerStore>();
    setState(() => _pendingRemoval.add(t.id));
    final r = await store.deleteTxn(t.id);
    if (!mounted) return;
    setState(() => _pendingRemoval.remove(t.id));
    if (!r.success) return;
    HapticFeedback.mediumImpact();
    final undo = r.undo;
    showSnack(context, s.transactionDeleted, onUndo: undo == null ? null : () => store.undo(undo));
  }

  Future<void> _deleteSelected() async {
    final s = AppStrings.of(context);
    final store = context.read<LedgerStore>();
    final n = _selected.length;
    final ok = await confirmDestructive(context, title: s.deleteTxnsTitle(n), body: s.deleteTxnsBody);
    if (!ok || !mounted) return;
    final r = await store.deleteTxns(Set.of(_selected));
    if (!mounted || !r.success) return;
    HapticFeedback.mediumImpact();
    setState(_selected.clear);
    final undo = r.undo;
    showSnack(context, s.txnsDeleted(n), onUndo: undo == null ? null : () => store.undo(undo));
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerStore>();
    final filters = context.watch<TxnFilterStore>();
    final account = ledger.activeAccount;
    if (account == null) return const SizedBox.shrink();
    final s = AppStrings.of(context);
    final c = context.colors;
    final res = filters.result;

    // Drop rows that no longer exist (deleted elsewhere) from the selection.
    _selected.removeWhere((id) => ledger.txn(id) == null);
    final rowIds = [for (final o in res.items) if (o is Txn) o.id];

    final slivers = <Widget>[
      SliverToBoxAdapter(child: _selecting ? _selectionBar(s, c, rowIds) : _topBar(s, c, filters)),
      if (_searching && !_selecting)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: appInputDecoration(
                context,
                hint: s.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: _PeriodNavigator(result: res)),
      ),
      if (!filters.filter.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          sliver: SliverToBoxAdapter(child: _ActiveChips(filter: filters.filter)),
        ),
      if (filters.hasFilters)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          sliver: SliverToBoxAdapter(child: _SummaryLine(result: res)),
        ),
    ];

    if (res.count == 0) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: filters.hasFilters
            ? EmptyState(
                emoji: '🔎',
                title: s.noMatchesTitle,
                body: s.noMatchesBody,
                actionLabel: s.clearFilters,
                onAction: () {
                  _search.clear();
                  filters.clearFilters();
                },
              )
            : EmptyState(
                emoji: '🧾',
                title: s.emptyPeriodTitle(_periodName(s, filters)),
                body: s.emptyPeriodBody,
                actionLabel: s.addTitle,
                onAction: () => showAddTxnSheet(context),
              ),
      ));
    } else if (res.grouped) {
      for (final g in res.items.whereType<DayGroup>()) {
        final rows = [for (final t in g.txns) if (!_pendingRemoval.contains(t.id)) t];
        if (rows.isEmpty) continue;
        slivers.add(SliverMainAxisGroup(
          key: ValueKey('g:${g.day.toIso8601String()}'),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DayHeaderDelegate(
                label: dayLabel(g.day, s).toUpperCase(),
                net: res.mixedCurrencies ? null : formatSigned(g.net, res.currency, whole: true),
                netPositive: g.net >= 0,
                colors: c,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: _rowList(rows, res),
            ),
          ],
        ));
      }
    } else {
      final rows = [
        for (final o in res.items)
          if (o is Txn && !_pendingRemoval.contains(o.id)) o,
      ];
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        sliver: _rowList(rows, res),
      ));
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: SafeArea(bottom: false, child: CustomScrollView(slivers: slivers)),
    );
  }

  Widget _rowList(List<Txn> rows, QueryResult res) {
    final s = AppStrings.of(context);
    final c = context.colors;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final t = rows[i];
          final tile = TxnTile(
            txn: t,
            showAccount: res.multiAccount,
            selectionMode: _selecting,
            selected: _selected.contains(t.id),
            onTap: () => _selecting ? _toggleSelected(t.id) : showTxnDetail(context, t.id),
            onLongPress: _selecting ? null : () => _startSelection(t.id),
          );
          if (_selecting) return KeyedSubtree(key: ValueKey(t.id), child: tile);
          return Dismissible(
            key: ValueKey(t.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: c.expense,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Semantics(
                label: s.delete,
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
            ),
            confirmDismiss: (_) => confirmDestructive(
              context,
              title: s.deleteTxnTitle,
              body: t.isTransfer ? s.deleteTransferBody : s.deleteTxnBody,
            ),
            onDismissed: (_) => _swipeDelete(t),
            child: tile,
          );
        },
        childCount: rows.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final idx = rows.indexWhere((t) => t.id == key.value);
          return idx < 0 ? null : idx;
        },
      ),
    );
  }

  Widget _topBar(AppStrings s, AppColors c, TxnFilterStore filters) {
    final count = filters.filter.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(s.tabTransactions, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            tooltip: _searching ? s.closeSearch : s.search,
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.search_off_rounded : Icons.search_rounded),
          ),
          IconButton(
            tooltip: s.filters,
            onPressed: () => showFilterSheet(context),
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              backgroundColor: c.primary,
              textColor: c.onPrimary,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          IconButton(
            tooltip: s.sort,
            onPressed: () => showSortSheet(context),
            icon: Badge(
              isLabelVisible: filters.sort != TxnSort.dateDesc,
              smallSize: 8,
              backgroundColor: c.primary,
              child: const Icon(Icons.swap_vert_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(AppStrings s, AppColors c, List<String> rowIds) {
    final allSelected = rowIds.isNotEmpty && rowIds.every(_selected.contains);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: s.clearSelection,
            onPressed: () => setState(_selected.clear),
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              s.selectedCount(_selected.length),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: allSelected ? s.clearSelection : s.selectAll,
            onPressed: () => setState(() {
              if (allSelected) {
                _selected.clear();
              } else {
                _selected.addAll(rowIds);
              }
            }),
            icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
          ),
          IconButton(
            tooltip: s.delete,
            onPressed: _deleteSelected,
            icon: Icon(Icons.delete_outline_rounded, color: c.expense),
          ),
        ],
      ),
    );
  }
}

String _periodName(AppStrings s, TxnFilterStore f) {
  final r = f.range;
  switch (f.kind) {
    case PeriodKind.all:
      return s.allTime;
    case PeriodKind.custom:
      {
        final p = f.customPreset;
        if (p != null) return s.presetLabel(p.name);
        return r == null ? s.customRange : rangeLabel(r, s);
      }
    case PeriodKind.month:
      if (r == null) return s.allTime;
      return cycleLabel(r, s);
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({required this.result});

  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final f = context.read<TxnFilterStore>();
    final isMonth = f.kind == PeriodKind.month;
    final cur = result.currency;
    String money(double v) => result.mixedCurrencies ? '—' : formatMoney(v, cur, whole: true);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: s.previousPeriod,
            onPressed: () => f.shiftMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickPeriod(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _periodName(s, f),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, size: 18, color: c.muted),
                      ],
                    ),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${s.periodIn} '),
                        TextSpan(text: money(result.income), style: TextStyle(color: c.income, fontWeight: FontWeight.w700)),
                        TextSpan(text: '  ·  ${s.periodOut} '),
                        TextSpan(text: money(result.expense), style: TextStyle(color: c.expense, fontWeight: FontWeight.w700)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMonth)
            IconButton(
              tooltip: s.nextPeriod,
              onPressed: () => f.shiftMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            )
          else
            IconButton(
              tooltip: s.clear,
              onPressed: () => f.showMonth(DateTime.now()),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }

  Future<void> _pickPeriod(BuildContext context) async {
    final s = AppStrings.of(context);
    final f = context.read<TxnFilterStore>();
    final now = DateTime.now();
    // The last 12 cycles, newest first.
    final cycles = <DateRange>[];
    var r = f.cycleOf(now);
    for (var i = 0; i < 12; i++) {
      cycles.add(r);
      r = f.cycleOf(DateTime(r.start.year, r.start.month, r.start.day - 1));
    }
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(s.choosePeriod, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final cy in cycles)
                      ListTile(
                        title: Text(cycleLabel(cy, s)),
                        onTap: () => Navigator.pop(ctx, cy),
                      ),
                    ListTile(
                      title: Text(s.allTime),
                      onTap: () => Navigator.pop(ctx, s.allTime),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked is DateRange) {
      f.showMonth(picked.start);
    } else if (picked is String) {
      f.showAllTime();
    }
  }
}

class _ActiveChips extends StatelessWidget {
  const _ActiveChips({required this.filter});

  final TxnFilter filter;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final ledger = context.read<LedgerStore>();
    final store = context.read<TxnFilterStore>();
    final account = ledger.activeAccount;
    final cur = account?.currency ?? kDefaultCurrency;
    final chips = <Widget>[];

    Widget chip(String label, VoidCallback onRemove) => InputChip(
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          onDeleted: onRemove,
          deleteButtonTooltipMessage: s.removeFilter(label),
        );

    for (final t in filter.types) {
      final dir = t == TxnType.transfer ? filter.transferDirection : null;
      final label = switch (dir) {
        TransferDirection.incoming => s.typeTransferIn,
        TransferDirection.outgoing => s.typeTransferOut,
        null => s.typeLabel(t.name),
      };
      chips.add(chip(label, () {
        store.setFilter(filter.copyWith(
          types: {...filter.types}..remove(t),
          transferDirection: t == TxnType.transfer ? null : filter.transferDirection,
        ));
      }));
    }
    for (final name in filter.categoryNames) {
      final display = ledger.categories
          .where((c) => c.name.toLowerCase() == name)
          .map((c) => '${c.emoji} ${c.name}')
          .firstOrNullSafe ?? name;
      chips.add(chip(display, () {
        store.setFilter(filter.copyWith(categoryNames: {...filter.categoryNames}..remove(name)));
      }));
    }
    if (filter.accountIds.isNotEmpty) {
      final label = filter.accountIds.length == 1
          ? (ledger.account(filter.accountIds.first)?.name ?? '')
          : s.accountsChip(filter.accountIds.length);
      chips.add(chip(label, () => store.setFilter(filter.copyWith(accountIds: const {}))));
    }
    final min = filter.minAmount, max = filter.maxAmount;
    if (min != null || max != null) {
      String m(double v) => formatMoney(v, cur, whole: v == v.roundToDouble());
      final label = min != null && max != null
          ? s.amountBetween(m(min), m(max))
          : (min != null ? s.amountAtLeast(m(min)) : s.amountAtMost(m(max!)));
      chips.add(chip(label, () => store.setFilter(filter.copyWith(minAmount: null, maxAmount: null))));
    }
    if (filter.counting != CountingFilter.all) {
      chips.add(chip(
        filter.counting == CountingFilter.counted ? s.countedOnly : s.excludedOnly,
        () => store.setFilter(filter.copyWith(counting: CountingFilter.all)),
      ));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNullSafe {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.result});

  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final parts = <InlineSpan>[TextSpan(text: s.resultsCount(result.count))];
    if (!result.mixedCurrencies) {
      if (result.income > 0) {
        parts.add(TextSpan(
          text: '  ·  ${formatSigned(result.income, result.currency, whole: true)}',
          style: TextStyle(color: c.income),
        ));
      }
      if (result.expense > 0) {
        parts.add(TextSpan(
          text: '  ·  ${formatSigned(-result.expense, result.currency, whole: true)}',
          style: TextStyle(color: c.expense),
        ));
      }
    }
    if (result.excludedCount > 0) {
      parts.add(TextSpan(text: '  ·  ${s.excludedCount(result.excludedCount)}'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: parts),
          style: TextStyle(
            color: c.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (result.mixedCurrencies)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(s.mixedCurrencies, style: TextStyle(color: c.warn, fontSize: 12)),
          ),
      ],
    );
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({
    required this.label,
    required this.net,
    required this.netPositive,
    required this.colors,
  });

  final String label;
  final String? net;
  final bool netPositive;
  final AppColors colors;

  static const double _height = 38;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: colors.bg,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: colors.muted,
              ),
            ),
          ),
          if (net != null)
            Text(
              net!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: netPositive ? colors.income : colors.expense,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate old) =>
      old.label != label || old.net != net || old.netPositive != netPositive || old.colors != colors;
}
