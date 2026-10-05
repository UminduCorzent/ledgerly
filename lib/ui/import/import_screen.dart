import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/export_import.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../../state/txn_filter_store.dart';
import '../widgets/common.dart';

/// Choose file → review rows (tick/untick) → choose accounts and strategy → import.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  static const int _previewLimit = 200;

  String? _fileName;
  bool _reading = false;
  ParseResult? _parsed;
  final Set<int> _excludedLines = {}; // unticked rows
  bool _matchAccounts = true;
  String? _singleAccountId;
  ImportStrategy _strategy = ImportStrategy.skipDuplicates;
  bool _importing = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'json'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() {
      _reading = true;
      _fileName = file.name;
      _parsed = null;
      _excludedLines.clear();
    });
    // Let the "Reading file…" state paint before parsing a large file.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final parsed = parseImportFile(file.name, bytes);
    if (!mounted) return;
    setState(() {
      _reading = false;
      _parsed = parsed;
      _matchAccounts = parsed.rows.any((r) => r.account != null);
    });
  }

  List<ImportRow> get _selected =>
      [for (final r in _parsed?.rows ?? const <ImportRow>[]) if (!_excludedLines.contains(r.line)) r];

  Future<void> _import() async {
    final s = AppStrings.of(context);
    final ledger = context.read<LedgerStore>();
    final rows = _selected;
    if (rows.isEmpty) return;
    if (_strategy == ImportStrategy.replaceAll) {
      final ok = await confirmDestructive(
        context,
        title: s.replaceConfirmTitle,
        body: s.replaceConfirmBody,
        action: s.replaceAction,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _importing = true);
    final outcome = await ledger.importRows(
      rows,
      singleAccountId: _matchAccounts ? null : (_singleAccountId ?? ledger.activeAccount?.id),
      strategy: _strategy,
    );
    if (!mounted) return;
    setState(() => _importing = false);
    if (!outcome.result.success) return;
    HapticFeedback.lightImpact();
    context.read<TxnFilterStore>().clearFilters();
    final undo = outcome.result.undo;
    final skippedRows = [
      ...?_parsed?.skipped.map((x) => (x.line, x.reason.name)),
      ...outcome.skipped.map((x) => (x.$1.line, x.$2.name)),
    ];
    final nav = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => _ResultSheet(
        added: outcome.added,
        skipped: skippedRows,
        extras: s.importExtras(outcome.newAccounts, outcome.newCategories),
        onUndo: undo == null ? null : () => ledger.undo(undo),
      ),
    );
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final ledger = context.watch<LedgerStore>();
    final parsed = _parsed;

    Widget title(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Text(t.toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.muted)),
        );

    final children = <Widget>[
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.importChooseBody, style: TextStyle(color: c.muted, height: 1.4)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reading || _importing ? null : _pick,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(
                _fileName == null ? s.importPick : _fileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_reading)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(s.importReading, style: TextStyle(color: c.muted)),
              ),
            if (parsed != null && !parsed.ok)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(s.importError(parsed.error!.name), style: TextStyle(color: c.expense)),
              ),
          ],
        ),
      ),
    ];

    if (parsed != null && parsed.ok) {
      final rows = parsed.rows;
      final dates = rows.map((r) => r.date).toList()..sort();
      final names = <String>{for (final r in rows) if (r.account != null) r.account!};
      final known = {for (final a in ledger.accounts) a.name.toLowerCase()};
      final selectedCount = _selected.length;

      children.addAll([
        title(s.importRows),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.importFound(rows.length), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (dates.isNotEmpty)
                Text('${dayLabel(dates.first, s)} – ${dayLabel(dates.last, s)}', style: TextStyle(color: c.muted)),
              if (parsed.skipped.isNotEmpty)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(s.importCantRead(parsed.skipped.length),
                        style: TextStyle(color: c.warn, fontWeight: FontWeight.w700, fontSize: 14)),
                    children: [
                      for (final k in parsed.skipped.take(_previewLimit))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${s.rowLabel(k.line)} · ${s.skipReason(k.reason.name)}'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              for (final r in rows.take(_previewLimit))
                CheckboxListTile(
                  key: ValueKey(r.line),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: !_excludedLines.contains(r.line),
                  onChanged: (on) => setState(() {
                    if (on == true) {
                      _excludedLines.remove(r.line);
                    } else {
                      _excludedLines.add(r.line);
                    }
                  }),
                  title: Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${s.rowLabel(r.line)} · ${dayLabel(r.date, s)} · ${r.type == TxnType.transfer ? s.typeTransfer : r.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: Text(
                    formatMoney(r.amount, r.currency ?? ledger.activeAccount?.currency ?? kDefaultCurrency),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: switch (r.type) {
                        TxnType.income => c.income,
                        TxnType.expense => c.expense,
                        TxnType.transfer => c.transfer,
                      },
                    ),
                  ),
                ),
              if (rows.length > _previewLimit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 8, 8),
                  child: Text(s.importShowingFirst(_previewLimit), style: TextStyle(color: c.muted, fontSize: 12.5)),
                ),
            ],
          ),
        ),
        title(s.importAccounts),
        _Choice(
          selected: _matchAccounts,
          title: s.importMatchAccounts,
          body: s.importMatchBody,
          onTap: () => setState(() => _matchAccounts = true),
          extra: _matchAccounts && names.isNotEmpty
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final n in names)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          known.contains(n.toLowerCase()) ? Icons.check_rounded : Icons.add_rounded,
                          size: 16,
                          color: known.contains(n.toLowerCase()) ? c.income : c.warn,
                        ),
                        label: Text(
                          known.contains(n.toLowerCase()) ? n : '$n (${s.importNewTag})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 8),
        _Choice(
          selected: !_matchAccounts,
          title: s.importSingle,
          body: s.importSingleBody,
          onTap: () => setState(() => _matchAccounts = false),
          extra: _matchAccounts
              ? null
              : DropdownButton<String>(
                  isExpanded: true,
                  value: _singleAccountId ?? ledger.activeAccount?.id,
                  onChanged: (v) => setState(() => _singleAccountId = v),
                  items: [
                    for (final a in ledger.accounts)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.emoji} ${a.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
        ),
        title(s.importStrategy),
        for (final (strategy, name, body) in [
          (ImportStrategy.skipDuplicates, s.skipDupTitle, s.skipDupBody),
          (ImportStrategy.addAll, s.addAllTitle, s.addAllBody),
          (ImportStrategy.replaceAll, s.replaceTitle, s.replaceBody),
        ]) ...[
          _Choice(
            selected: _strategy == strategy,
            title: name,
            body: body,
            danger: strategy == ImportStrategy.replaceAll,
            onTap: () => setState(() => _strategy = strategy),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: selectedCount == 0 || _importing ? null : _import,
          icon: _importing
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_done_rounded),
          label: Text(s.importButton(selectedCount)),
        ),
      ]);
    }

    return Scaffold(
      appBar: AppTopBar(title: s.importTitle),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: children),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.title,
    required this.body,
    required this.onTap,
    this.extra,
    this.danger = false,
  });

  final bool selected;
  final String title;
  final String body;
  final VoidCallback onTap;
  final Widget? extra;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = danger ? c.expense : c.primary;
    return Material(
      color: selected ? accent.withValues(alpha: 0.07) : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? accent : c.line, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? accent : c.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? c.expense : null)),
                        Text(body, style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              if (extra != null) ...[const SizedBox(height: 10), extra!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.added, required this.skipped, required this.extras, this.onUndo});

  final int added;
  final List<(int, String)> skipped;
  final String extras;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.check_circle_rounded, color: c.income, size: 44),
              const SizedBox(height: 8),
              Text(
                s.importDone(added, skipped.length),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              if (extras.isNotEmpty)
                Text(extras, textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
              if (skipped.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(s.skippedTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (line, reason) in skipped.take(200))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('${s.rowLabel(line)} · ${s.skipReason(reason)}', style: TextStyle(color: c.muted)),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (onUndo != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          onUndo!();
                          Navigator.pop(context);
                        },
                        child: Text(s.undo),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(s.done)),
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
