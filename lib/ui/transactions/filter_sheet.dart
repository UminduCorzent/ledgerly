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
import '../widgets/common.dart';
import '../widgets/segmented.dart';

Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _FilterSheet(),
  );
}

/// One scrolling page (instead of tabs): date, type, accounts, categories,
/// amount, counting. Nothing applies until "Show N results".
class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TxnFilterStore _store = context.read<TxnFilterStore>();
  late final LedgerStore _ledger = context.read<LedgerStore>();

  late TxnFilter _f = _store.filter;
  late PeriodKind _kind = _store.kind;
  late DateTime _anchor = _store.monthAnchor;
  late DateRange? _custom = _store.kind == PeriodKind.custom ? _store.range : null;
  late DatePreset? _preset = _store.customPreset;

  late final TextEditingController _min =
      TextEditingController(text: _fmtInput(_store.filter.minAmount));
  late final TextEditingController _max =
      TextEditingController(text: _fmtInput(_store.filter.maxAmount));
  final TextEditingController _catSearch = TextEditingController();
  String _catQuery = '';

  static String _fmtInput(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _catSearch.dispose();
    super.dispose();
  }

  DateRange? get _range => switch (_kind) {
        PeriodKind.month => _store.cycleOf(_anchor),
        PeriodKind.all => null,
        PeriodKind.custom => _custom,
      };

  bool get _amountInvalid {
    final a = _f.minAmount, b = _f.maxAmount;
    return a != null && b != null && a > b;
  }

  /// Which preset chip shows as selected for the staged period.
  DatePreset? get _selectedPreset {
    final now = DateTime.now();
    switch (_kind) {
      case PeriodKind.all:
        return DatePreset.allTime;
      case PeriodKind.custom:
        return _preset;
      case PeriodKind.month:
        {
          final current = _store.cycleOf(now);
          final staged = _store.cycleOf(_anchor);
          if (staged == current) return DatePreset.thisMonth;
          final prev = _store.cycleOf(
            DateTime(current.start.year, current.start.month, current.start.day - 1),
          );
          return staged == prev ? DatePreset.lastMonth : null;
        }
    }
  }

  void _pickPreset(DatePreset p) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      switch (p) {
        case DatePreset.thisMonth:
          _kind = PeriodKind.month;
          _anchor = now;
        case DatePreset.lastMonth:
          {
            final c = _store.cycleOf(now);
            _kind = PeriodKind.month;
            _anchor = DateTime(c.start.year, c.start.month, c.start.day - 1);
          }
        case DatePreset.allTime:
          _kind = PeriodKind.all;
        default:
          _kind = PeriodKind.custom;
          _custom = presetRange(p, now, _store.cycleOf);
          _preset = p;
      }
    });
  }

  Future<void> _pickCustom() async {
    final r = _range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: r == null || r.end == null
          ? null
          : DateTimeRange(start: r.start, end: r.lastDay ?? r.start),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _kind = PeriodKind.custom;
      _preset = null;
      // The picker's end date is inclusive; ranges here are end-exclusive.
      _custom = DateRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
      );
    });
  }

  /// Account chips: an empty set means "active account only".
  Set<String> get _effectiveAccounts {
    final active = _ledger.activeAccount?.id;
    return _f.accountIds.isEmpty ? {if (active != null) active} : _f.accountIds;
  }

  void _toggleAccount(String id) {
    final active = _ledger.activeAccount?.id;
    final next = {..._effectiveAccounts};
    if (!next.remove(id)) next.add(id);
    final onlyActive = next.isEmpty || (next.length == 1 && next.first == active);
    setState(() => _f = _f.copyWith(accountIds: onlyActive ? const {} : next));
  }

  void _clearAll() {
    HapticFeedback.selectionClick();
    setState(() {
      _f = TxnFilter.none;
      _kind = PeriodKind.month;
      _anchor = DateTime.now();
      _custom = null;
      _preset = null;
      _min.clear();
      _max.clear();
    });
  }

  void _apply() {
    _store.applyAll(
      filter: _f,
      kind: _kind,
      anchor: _anchor,
      custom: _custom,
      preset: _preset,
    );
    Navigator.pop(context);
  }

  double? _parse(String v) {
    final x = double.tryParse(v.trim());
    return x == null || x < 0 ? null : x;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final media = MediaQuery.of(context);
    final accounts = _ledger.accounts;
    final count = _store.countFor(_f, _range);

    // Category chips from every selected account, merged by name.
    final seen = <String>{};
    final cats = <(String, String)>[]; // (lower name, display)
    for (final accId in _effectiveAccounts) {
      for (final cat in _ledger.categoriesFor(accId)) {
        final lower = cat.name.toLowerCase();
        if (seen.add(lower)) cats.add((lower, '${cat.emoji} ${cat.name}'));
      }
    }
    final q = _catQuery.trim().toLowerCase();
    final shownCats = q.isEmpty ? cats : cats.where((e) => e.$1.contains(q)).toList();

    Widget title(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(
            t.toUpperCase(),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.muted),
          ),
        );

    final r = _range;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.filters, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    title(s.filterDate),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in DatePreset.values)
                          ChoiceChip(
                            label: Text(s.presetLabel(p.name)),
                            selected: _selectedPreset == p,
                            onSelected: (_) => _pickPreset(p),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.date_range_rounded, size: 18),
                          label: Text(
                            _kind == PeriodKind.custom && _preset == null && r != null
                                ? rangeLabel(r)
                                : s.pickCustomRange,
                          ),
                          onPressed: _pickCustom,
                        ),
                      ],
                    ),
                    title(s.filterType),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in TxnType.values)
                          FilterChip(
                            label: Text(s.typeLabel(t.name)),
                            selected: _f.types.contains(t),
                            onSelected: (on) => setState(() {
                              final next = {..._f.types};
                              on ? next.add(t) : next.remove(t);
                              _f = _f.copyWith(types: next);
                            }),
                          ),
                      ],
                    ),
                    if (accounts.length > 1) ...[
                      title(s.filterAccounts),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in accounts)
                            FilterChip(
                              label: Text('${a.emoji} ${a.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                              selected: _effectiveAccounts.contains(a.id),
                              onSelected: (_) => _toggleAccount(a.id),
                            ),
                        ],
                      ),
                    ],
                    title(s.filterCategories),
                    if (cats.length > 12)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _catSearch,
                          onChanged: (v) => setState(() => _catQuery = v),
                          decoration: appInputDecoration(
                            context,
                            hint: s.categorySearchHint,
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (lower, display) in shownCats)
                          FilterChip(
                            label: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
                            selected: _f.categoryNames.contains(lower),
                            onSelected: (on) => setState(() {
                              final next = {..._f.categoryNames};
                              on ? next.add(lower) : next.remove(lower);
                              _f = _f.copyWith(categoryNames: next);
                            }),
                          ),
                      ],
                    ),
                    title(s.filterAmount),
                    Row(
                      children: [
                        Expanded(child: _amountField(context, _min, s.amountMin, (v) {
                          setState(() => _f = _f.copyWith(minAmount: _parse(v)));
                        })),
                        const SizedBox(width: 10),
                        Expanded(child: _amountField(context, _max, s.amountMax, (v) {
                          setState(() => _f = _f.copyWith(maxAmount: _parse(v)));
                        })),
                      ],
                    ),
                    if (_amountInvalid)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                        child: Text(s.amountRangeError, style: TextStyle(color: c.expense, fontSize: 12.5)),
                      ),
                    title(s.filterCounting),
                    Segmented<CountingFilter>(
                      values: CountingFilter.values,
                      labels: [s.countingAll, s.countingCounted, s.countingExcluded],
                      selected: _f.counting,
                      onChanged: (v) => setState(() => _f = _f.copyWith(counting: v)),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _clearAll, child: Text(s.clear)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _amountInvalid ? null : _apply,
                      child: Text(s.showResults(count)),
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

  Widget _amountField(
    BuildContext context,
    TextEditingController controller,
    String hint,
    ValueChanged<String> onChanged,
  ) {
    final cur = currencyOf(_ledger.activeAccount?.currency ?? kDefaultCurrency);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: onChanged,
      decoration: appInputDecoration(
        context,
        hint: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Text(cur.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ).copyWith(prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0)),
    );
  }
}
