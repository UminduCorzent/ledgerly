import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/month_cycle.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';
import '../widgets/segmented.dart';

/// What "this month" means for the active account. Every change saves immediately.
class MonthCycleScreen extends StatefulWidget {
  const MonthCycleScreen({super.key});

  @override
  State<MonthCycleScreen> createState() => _MonthCycleScreenState();
}

class _MonthCycleScreenState extends State<MonthCycleScreen> {
  int? _dragDay; // slider value while dragging; saved on release
  late final TextEditingController _min = TextEditingController();
  String? _minFor; // account the text field was filled for

  @override
  void dispose() {
    _min.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final ledger = context.watch<LedgerStore>();
    final account = ledger.activeAccount;
    if (account == null) return const SizedBox.shrink();
    final cfg = ledger.cycleConfig(account.id);
    final now = DateTime.now();
    final current = ledger.cycleContaining(account.id, now);
    final runningLong = ledger.cycleRunningLongDay(account.id, now);
    final payday = cfg.mode == CycleMode.payday;
    final day = _dragDay ?? cfg.startDay;

    if (_minFor != account.id) {
      _minFor = account.id;
      _min.text = cfg.minAmount > 0 ? amountText(cfg.minAmount) : '';
    }

    void save(CycleConfig next) => ledger.setCycleConfig(account.id, next);

    Widget section(String title, {String? body, required Widget child}) => Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (body != null) ...[
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
              const SizedBox(height: 10),
              child,
            ],
          ),
        );

    return Scaffold(
      appBar: AppTopBar(title: s.monthCycle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // Preview of the cycle in effect right now.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.tinted(c.primary),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Row(
              children: [
                EmojiAvatar(emoji: account.emoji, color: Color(account.color), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.currentCycle, style: TextStyle(color: c.muted, fontSize: 12.5)),
                      Text(
                        rangeLabel(current, s),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      if (runningLong != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            s.runningLong(runningLong),
                            style: TextStyle(color: c.warn, fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Segmented<CycleMode>(
            values: CycleMode.values,
            labels: [s.cycleModeFixed, s.cycleModePayday],
            selected: cfg.mode,
            onChanged: (m) {
              HapticFeedback.selectionClick();
              save(cfg.copyWith(mode: m));
            },
          ),
          const SizedBox(height: 8),
          Text(
            payday ? s.cycleModePaydayBody : s.cycleModeFixedBody,
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
          section(
            payday ? s.fallbackStartDayTitle : s.startDayTitle,
            body: payday ? s.fallbackStartDayBody : null,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.dayN(day),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  Slider(
                    min: 1,
                    max: 31,
                    divisions: 30,
                    value: day.toDouble(),
                    label: '$day',
                    onChanged: (v) => setState(() => _dragDay = v.round()),
                    onChangeEnd: (v) {
                      setState(() => _dragDay = null);
                      save(cfg.copyWith(startDay: v.round()));
                    },
                  ),
                  Text(
                    day == 1 ? s.calendarMonthHint : (day > 28 ? s.shortMonthHint : ''),
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          if (payday) ..._paydaySections(context, ledger, account.id, cfg, section, save),
        ],
      ),
    );
  }

  List<Widget> _paydaySections(
    BuildContext context,
    LedgerStore ledger,
    String accountId,
    CycleConfig cfg,
    Widget Function(String, {String? body, required Widget child}) section,
    void Function(CycleConfig) save,
  ) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final cats = ledger.categories;
    final currency = ledger.account(accountId)?.currency ?? kDefaultCurrency;
    final starts = ledger.recentCycleStarts(accountId);

    return [
      section(
        s.paydayCategories,
        body: cfg.anchorCategoryIds.isEmpty
            ? s.paydayCategoriesAny
            : s.paydayCategoriesCount(cfg.anchorCategoryIds.length),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in cats)
                  FilterChip(
                    label: Text('${cat.emoji} ${cat.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: cfg.anchorCategoryIds.contains(cat.id),
                    onSelected: (on) {
                      final next = {...cfg.anchorCategoryIds};
                      on ? next.add(cat.id) : next.remove(cat.id);
                      save(cfg.copyWith(anchorCategoryIds: next));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(s.paydayTransfersNote, style: TextStyle(color: c.muted, fontSize: 12.5)),
          ],
        ),
      ),
      section(
        s.minimumAmount,
        body: s.minimumAmountBody,
        child: TextField(
          controller: _min,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          onChanged: (v) => save(cfg.copyWith(minAmount: double.tryParse(v) ?? 0)),
          decoration: appInputDecoration(
            context,
            hint: '0',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Text(currencyOf(currency).symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ).copyWith(prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0)),
        ),
      ),
      section(
        s.cooldown,
        body: s.cooldownBody,
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: s.decrease,
              onPressed: cfg.cooldownDays <= 1
                  ? null
                  : () => save(cfg.copyWith(cooldownDays: cfg.cooldownDays - 1)),
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Text(
                s.daysN(cfg.cooldownDays),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filledTonal(
              tooltip: s.increase,
              onPressed: cfg.cooldownDays >= 60
                  ? null
                  : () => save(cfg.copyWith(cooldownDays: cfg.cooldownDays + 1)),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
      section(
        s.detectedStarts,
        child: SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: starts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(s.noDetectedStarts, style: TextStyle(color: c.muted)),
                )
              : Column(
                  children: [
                    for (final (date, txn) in starts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded, color: c.income, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dayLabel(date, s), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    txn == null
                                        ? s.pinnedManually
                                        : txn.isTransfer
                                            ? s.transferFromAccount(
                                                ledger.account(txn.counterAccountId)?.name ?? txn.description)
                                            : (ledger.category(txn.categoryId)?.name ?? txn.description),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: c.muted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            if (txn != null)
                              Text(
                                formatMoney(txn.amount, currency, whole: true),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
      section(
        s.pinStart,
        body: s.pinStartBody,
        child: Material(
          color: c.surface2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: cfg.pinnedStart ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: now,
              );
              if (picked != null) save(cfg.copyWith(pinnedStart: picked));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Row(
                children: [
                  Icon(Icons.push_pin_outlined, color: c.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cfg.pinnedStart == null ? s.notSet : dayLabel(cfg.pinnedStart!, s),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (cfg.pinnedStart != null)
                    IconButton(
                      tooltip: s.clearPin,
                      onPressed: () => save(cfg.copyWith(pinnedStart: null)),
                      icon: const Icon(Icons.close_rounded),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Plain number for an amount text field (no grouping).
String amountText(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
