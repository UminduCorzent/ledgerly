import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/date_range.dart';
import '../../domain/export_import.dart';
import '../../domain/txn_query.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';
import 'file_ready_sheet.dart';
import 'pdf_report.dart';

enum ExportFormat { csv, excel, pdf }

const int kExportCap = 10000;

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  ExportFormat _format = ExportFormat.csv;
  DatePreset? _preset = DatePreset.thisMonth;
  DateRange? _custom;
  late Set<String> _accounts = {context.read<LedgerStore>().activeAccount!.id};
  bool _busy = false;

  DateRange? _range(LedgerStore ledger) {
    if (_preset == null) return _custom;
    final active = ledger.activeAccount!.id;
    return presetRange(_preset!, DateTime.now(), (d) => ledger.cycleContaining(active, d));
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _preset = null;
      _custom = DateRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
      );
    });
  }

  String _periodLabel(AppStrings s, DateRange? r) {
    if (_preset != null) return s.presetLabel(_preset!.name);
    return r == null ? s.allTime : rangeLabel(r, s);
  }

  Future<void> _export() async {
    final s = AppStrings.of(context);
    final ledger = context.read<LedgerStore>();
    final range = _range(ledger);
    final all = ledger.exportRows(_accounts, range, cap: kExportCap);
    if (all.isEmpty) return;
    setState(() => _busy = true);
    final stamp = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final base = 'ledgerly-${stamp.year}${two(stamp.month)}${two(stamp.day)}-${two(stamp.hour)}${two(stamp.minute)}';
    try {
      late final Uint8List bytes;
      late final String name;
      late final String mime;
      switch (_format) {
        case ExportFormat.csv:
          // BOM so Excel opens UTF-8 (emoji, currency symbols) correctly.
          bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCsv(all))]);
          name = '$base.csv';
          mime = 'text/csv';
        case ExportFormat.excel:
          bytes = toXlsx(all);
          name = '$base.xlsx';
          mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        case ExportFormat.pdf:
          bytes = await buildPdfReport(
            rows: all.where((r) => !r.excluded).toList(),
            period: _periodLabel(s, range),
            accountNames: [for (final id in _accounts) ledger.account(id)?.name ?? ''],
            s: s,
          );
          name = '$base.pdf';
          mime = 'application/pdf';
      }
      if (!mounted) return;
      setState(() => _busy = false);
      HapticFeedback.lightImpact();
      await showFileReadySheet(context, bytes: bytes, fileName: name, mimeType: mime);
    } catch (e) {
      debugPrint('Export failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, s.fileFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final ledger = context.watch<LedgerStore>();
    final accounts = ledger.accounts;
    _accounts.removeWhere((id) => ledger.account(id) == null);
    if (_accounts.isEmpty && ledger.activeAccount != null) _accounts = {ledger.activeAccount!.id};
    final range = _range(ledger);
    var total = 0;
    for (final id in _accounts) {
      total += ledger.txnsFor(id).where((t) => range == null || range.contains(t.date)).length;
    }
    final count = total > kExportCap ? kExportCap : total;

    Widget title(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Text(t.toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.muted)),
        );

    Widget formatCard(ExportFormat f, IconData icon, String name, String body) {
      final sel = f == _format;
      return Material(
        color: sel ? c.primary.withValues(alpha: 0.08) : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: sel ? c.primary : c.line, width: sel ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _format = f),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: sel ? c.primary : c.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(body, style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (sel) Icon(Icons.check_circle_rounded, color: c.primary),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppTopBar(title: s.exportTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          title(s.exportFormat),
          formatCard(ExportFormat.csv, Icons.table_rows_outlined, s.formatCsv, s.formatCsvBody),
          const SizedBox(height: 8),
          formatCard(ExportFormat.excel, Icons.grid_on_rounded, s.formatExcel, s.formatExcelBody),
          const SizedBox(height: 8),
          formatCard(ExportFormat.pdf, Icons.picture_as_pdf_outlined, s.formatPdf, s.formatPdfBody),
          title(s.exportPeriod),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in const [
                DatePreset.thisMonth,
                DatePreset.lastMonth,
                DatePreset.last3Months,
                DatePreset.thisYear,
                DatePreset.allTime,
              ])
                ChoiceChip(
                  label: Text(s.presetLabel(p.name)),
                  selected: _preset == p,
                  onSelected: (_) => setState(() => _preset = p),
                ),
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(_preset == null && _custom != null ? rangeLabel(_custom!, s) : s.pickCustomRange),
                onPressed: _pickCustom,
              ),
            ],
          ),
          if (range != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(rangeLabel(range, s), style: TextStyle(color: c.muted, fontSize: 12.5)),
            ),
          if (accounts.length > 1) ...[
            title(s.exportAccounts),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in accounts)
                  FilterChip(
                    label: Text('${a.emoji} ${a.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: _accounts.contains(a.id),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _accounts = {..._accounts, a.id};
                      } else if (_accounts.length > 1) {
                        _accounts = {..._accounts}..remove(a.id);
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text(
            _format == ExportFormat.pdf ? s.excludedNotePdf : s.excludedNoteTable,
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
          if (total > kExportCap)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.exportCapped(kExportCap), style: TextStyle(color: c.warn, fontSize: 12.5)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: count == 0 || _busy ? null : _export,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined),
            label: Text(s.exportButton(count)),
          ),
        ],
      ),
    );
  }
}
