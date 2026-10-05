import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/txn.dart';

// Export tables and import parsing (CSV, Excel, JSON). Pure Dart so it can be
// unit-tested; UI strings stay out of here (headers are fixed English on purpose
// so files round-trip regardless of app language).

const List<String> kExportHeader = [
  'Date',
  'Type',
  'Account',
  'Category',
  'Description',
  'Amount',
  'Currency',
  'Notes',
  'Excluded',
  'Transfer direction',
  'Counterpart account',
];

final DateFormat _exportDate = DateFormat('yyyy-MM-dd HH:mm', 'en_US');

/// One exported transaction row (both legs of a transfer are exported, so a
/// re-import can pair them back up).
class ExportRow {
  const ExportRow({
    required this.date,
    required this.type,
    required this.account,
    required this.category,
    required this.description,
    required this.amount,
    required this.currency,
    this.notes,
    this.excluded = false,
    this.direction,
    this.counterpart,
  });

  final DateTime date;
  final TxnType type;
  final String account;
  final String category;
  final String description;
  final double amount;
  final String currency;
  final String? notes;
  final bool excluded;
  final TransferDirection? direction;
  final String? counterpart;

  List<String> toCells() => [
        _exportDate.format(date),
        type.name,
        account,
        category,
        description,
        amount.toStringAsFixed(2),
        currency,
        notes ?? '',
        excluded ? 'true' : 'false',
        switch (direction) {
          TransferDirection.outgoing => 'out',
          TransferDirection.incoming => 'in',
          null => '',
        },
        counterpart ?? '',
      ];
}

String toCsv(List<ExportRow> rows) => const ListToCsvConverter().convert([
      kExportHeader,
      for (final r in rows) r.toCells(),
    ]);

Uint8List toXlsx(List<ExportRow> rows) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  const name = 'Transactions';
  final sheet = excel[name];
  sheet.appendRow([for (final h in kExportHeader) TextCellValue(h)]);
  for (final r in rows) {
    final cells = r.toCells();
    sheet.appendRow([
      for (var i = 0; i < cells.length; i++)
        i == 5 ? DoubleCellValue(r.amount) : TextCellValue(cells[i]),
    ]);
  }
  if (defaultSheet != null && defaultSheet != name) excel.delete(defaultSheet);
  return Uint8List.fromList(excel.encode() ?? const []);
}

// ---------------------------------------------------------------- import

enum ImportError { unsupportedFormat, emptyFile, missingColumns, unreadable }

enum SkipReason { badType, badAmount, badDate, unreadable }

class ImportRow {
  const ImportRow({
    required this.line,
    required this.date,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    this.account,
    this.currency,
    this.notes,
    this.excluded = false,
    this.direction,
    this.counterpart,
  });

  /// 1-based data row number (header excluded), shown to the user.
  final int line;
  final DateTime date;
  final TxnType type;
  final double amount;
  final String? account;
  final String category;
  final String description;
  final String? currency;
  final String? notes;
  final bool excluded;
  final TransferDirection? direction;
  final String? counterpart;
}

class SkippedRow {
  const SkippedRow(this.line, this.reason);

  final int line;
  final SkipReason reason;
}

class ParseResult {
  const ParseResult({this.rows = const [], this.skipped = const [], this.error});

  final List<ImportRow> rows;
  final List<SkippedRow> skipped;
  final ImportError? error;

  bool get ok => error == null;
}

/// "Counterpart account" → "counterpartaccount".
String _normHeader(String h) => h.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

final List<DateFormat> _dateFormats = [
  DateFormat('yyyy-MM-dd HH:mm', 'en_US'),
  DateFormat('yyyy-MM-dd', 'en_US'),
  DateFormat('dd MMM yyyy', 'en_US'),
  DateFormat('dd MMM yyyy, hh:mm a', 'en_US'),
  DateFormat('dd/MM/yyyy', 'en_US'),
];

DateTime? parseImportDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  for (final f in _dateFormats) {
    try {
      return f.parseStrict(s);
    } catch (_) {}
  }
  return DateTime.tryParse(s);
}

TxnType? _parseType(String raw) => switch (raw.trim().toLowerCase()) {
      'income' => TxnType.income,
      'expense' => TxnType.expense,
      'transfer' => TxnType.transfer,
      _ => null,
    };

TransferDirection? _parseDirection(String raw) => switch (raw.trim().toLowerCase()) {
      'out' || 'outgoing' => TransferDirection.outgoing,
      'in' || 'incoming' => TransferDirection.incoming,
      _ => null,
    };

bool _parseBool(String raw) => const {'true', '1', 'yes', 'y'}.contains(raw.trim().toLowerCase());

String? _nonEmpty(String? s) {
  final t = s?.trim() ?? '';
  return t.isEmpty ? null : t;
}

/// Turns header-keyed records into rows. Required columns: date, type, amount.
ParseResult _fromRecords(List<Map<String, String>> records, Set<String> headers) {
  if (records.isEmpty) return const ParseResult(error: ImportError.emptyFile);
  if (!headers.containsAll(const {'date', 'type', 'amount'})) {
    return const ParseResult(error: ImportError.missingColumns);
  }
  final rows = <ImportRow>[];
  final skipped = <SkippedRow>[];
  for (var i = 0; i < records.length; i++) {
    final r = records[i];
    final line = i + 1;
    if (r.values.every((v) => v.trim().isEmpty)) continue; // blank line
    final date = parseImportDate(r['date'] ?? '');
    if (date == null) {
      skipped.add(SkippedRow(line, SkipReason.badDate));
      continue;
    }
    final type = _parseType(r['type'] ?? '');
    if (type == null) {
      skipped.add(SkippedRow(line, SkipReason.badType));
      continue;
    }
    final rawAmount = (r['amount'] ?? '').replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount)?.abs();
    if (amount == null || amount <= 0 || !amount.isFinite) {
      skipped.add(SkippedRow(line, SkipReason.badAmount));
      continue;
    }
    final category = _nonEmpty(r['category']) ?? 'Other';
    rows.add(ImportRow(
      line: line,
      date: date,
      type: type,
      amount: amount,
      account: _nonEmpty(r['account']),
      category: category,
      description: _nonEmpty(r['description']) ?? category,
      currency: _nonEmpty(r['currency'])?.toUpperCase(),
      notes: _nonEmpty(r['notes']),
      excluded: _parseBool(r['excluded'] ?? ''),
      direction: _parseDirection(r['transferdirection'] ?? ''),
      counterpart: _nonEmpty(r['counterpartaccount']),
    ));
  }
  // Only blank lines below the header.
  if (rows.isEmpty && skipped.isEmpty) return const ParseResult(error: ImportError.emptyFile);
  return ParseResult(rows: rows, skipped: skipped);
}

ParseResult _fromTable(List<List<String>> table) {
  if (table.isEmpty) return const ParseResult(error: ImportError.emptyFile);
  final header = table.first.map(_normHeader).toList();
  final records = <Map<String, String>>[
    for (final row in table.skip(1))
      {
        for (var c = 0; c < header.length; c++) header[c]: c < row.length ? row[c] : '',
      },
  ];
  return _fromRecords(records, header.toSet());
}

String _cellText(Data? d) {
  final v = d?.value;
  return switch (v) {
    null => '',
    DateCellValue() => DateTime(v.year, v.month, v.day).toIso8601String(),
    DateTimeCellValue() => v.asDateTimeLocal().toIso8601String(),
    IntCellValue() => v.value.toString(),
    DoubleCellValue() => v.value.toString(),
    _ => v.toString(),
  };
}

/// Parses an import file by extension: .csv, .xlsx (first sheet) or .json.
ParseResult parseImportFile(String fileName, Uint8List bytes) {
  final lower = fileName.toLowerCase();
  try {
    if (lower.endsWith('.csv')) {
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('﻿')) text = text.substring(1); // Excel's BOM
      final table = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
          .convert(text.replaceAll('\r\n', '\n'))
          .map((r) => r.map((c) => c.toString()).toList())
          .toList();
      return _fromTable(table);
    }
    if (lower.endsWith('.xlsx')) {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return const ParseResult(error: ImportError.emptyFile);
      final sheet = excel.tables.values.first;
      final table = [
        for (final row in sheet.rows) [for (final cell in row) _cellText(cell)],
      ];
      return _fromTable(table);
    }
    if (lower.endsWith('.json')) {
      final decoded = jsonDecode(utf8.decode(bytes));
      final list = decoded is List
          ? decoded
          : (decoded is Map ? decoded['transactions'] : null);
      if (list is! List) return const ParseResult(error: ImportError.unreadable);
      final records = <Map<String, String>>[];
      final headers = <String>{};
      for (final item in list) {
        if (item is! Map) {
          records.add(const {});
          continue;
        }
        final rec = <String, String>{
          for (final e in item.entries) _normHeader(e.key.toString()): e.value?.toString() ?? '',
        };
        headers.addAll(rec.keys);
        records.add(rec);
      }
      return _fromRecords(records, headers);
    }
    return const ParseResult(error: ImportError.unsupportedFormat);
  } catch (_) {
    return const ParseResult(error: ImportError.unreadable);
  }
}

/// Duplicate signature: account, day, type, category, description, amount (2 dp).
String duplicateKey({
  required String accountKey,
  required DateTime date,
  required TxnType type,
  required String category,
  required String description,
  required double amount,
}) =>
    [
      accountKey.toLowerCase(),
      '${date.year}-${date.month}-${date.day}',
      type.name,
      category.trim().toLowerCase(),
      description.trim().toLowerCase(),
      amount.toStringAsFixed(2),
    ].join('|');

/// Pairs transfer rows into (outgoing, incoming) legs. A pair matches when the
/// accounts mirror each other, the day and description are equal and the
/// directions are opposite. Returns pairs and the rows left unpaired.
(List<(ImportRow, ImportRow?)>, List<ImportRow>) pairTransfers(List<ImportRow> transfers) {
  final pending = List<ImportRow>.of(transfers);
  final pairs = <(ImportRow, ImportRow?)>[];
  final unpaired = <ImportRow>[];
  while (pending.isNotEmpty) {
    final a = pending.removeAt(0);
    final idx = pending.indexWhere((b) =>
        b.direction != null &&
        a.direction != null &&
        b.direction != a.direction &&
        (b.account ?? '').toLowerCase() == (a.counterpart ?? '').toLowerCase() &&
        (b.counterpart ?? '').toLowerCase() == (a.account ?? '').toLowerCase() &&
        b.date.year == a.date.year &&
        b.date.month == a.date.month &&
        b.date.day == a.date.day &&
        b.description.toLowerCase() == a.description.toLowerCase());
    if (idx >= 0) {
      final b = pending.removeAt(idx);
      final out = a.direction == TransferDirection.outgoing ? a : b;
      final inn = a.direction == TransferDirection.outgoing ? b : a;
      pairs.add((out, inn));
    } else {
      unpaired.add(a);
    }
  }
  return (pairs, unpaired);
}
