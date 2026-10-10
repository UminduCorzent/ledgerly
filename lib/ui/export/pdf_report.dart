import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../domain/export_import.dart';
import '../../models/txn.dart';

/// A printable summary (no row list): totals and breakdowns, one section per
/// currency. Excluded transactions are left out by the caller.
Future<Uint8List> buildPdfReport({
  required List<ExportRow> rows,
  required String period,
  required List<String> accountNames,
  required AppStrings s,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-400.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-700.ttf'));
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: s.pdfTitle,
  );

  const brand = PdfColor.fromInt(0xFF2563EB);
  const income = PdfColor.fromInt(0xFF0E9F6E);
  const expense = PdfColor.fromInt(0xFFE11D48);
  const muted = PdfColor.fromInt(0xFF5B6B82);
  const line = PdfColor.fromInt(0xFFE3E9F3);

  final byCurrency = <String, List<ExportRow>>{};
  for (final r in rows) {
    (byCurrency[r.currency] ??= []).add(r);
  }

  pw.Widget tile(String label, String value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: line),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(color: muted, fontSize: 9)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: pw.TextStyle(color: color, fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  pw.Widget table(String title, Map<String, double> amounts, double total, String currency) {
    final sorted = amounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 14),
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: [s.pdfCategory, s.pdfAmount, s.pdfShare],
          data: [
            for (final e in sorted)
              [
                e.key,
                formatMoney(e.value, currency),
                total <= 0 ? '—' : '${(e.value / total * 100).toStringAsFixed(1)}%',
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEF3FB)),
          cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
          border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: line, width: 0.5)),
        ),
      ],
    );
  }

  final generated = DateFormat('d MMM yyyy, HH:mm', 'en_US').format(DateTime.now());

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(s.pdfPage(ctx.pageNumber, ctx.pagesCount), style: const pw.TextStyle(color: muted, fontSize: 8)),
    ),
    build: (ctx) => [
      pw.Text(s.pdfTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: brand)),
      pw.SizedBox(height: 6),
      pw.Text('${s.pdfPeriod}: $period', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('${s.pdfAccounts}: ${accountNames.join(', ')}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('${s.pdfGenerated}: $generated', style: const pw.TextStyle(fontSize: 10, color: muted)),
      if (byCurrency.isEmpty)
        pw.Padding(padding: const pw.EdgeInsets.only(top: 24), child: pw.Text(s.pdfNoData)),
      for (final entry in byCurrency.entries) ...() {
        final cur = entry.key;
        var inc = 0.0, exp = 0.0;
        final spend = <String, double>{};
        final sources = <String, double>{};
        for (final r in entry.value) {
          // Transfers count as money in / out, the same as the app's totals.
          if (r.type == TxnType.transfer) {
            final key = s.transfersCategory;
            if (r.direction == TransferDirection.outgoing) {
              exp += r.amount;
              spend[key] = (spend[key] ?? 0) + r.amount;
            } else {
              inc += r.amount;
              sources[key] = (sources[key] ?? 0) + r.amount;
            }
          } else if (r.type == TxnType.income) {
            inc += r.amount;
            sources[r.category] = (sources[r.category] ?? 0) + r.amount;
          } else {
            exp += r.amount;
            spend[r.category] = (spend[r.category] ?? 0) + r.amount;
          }
        }
        return <pw.Widget>[
          pw.SizedBox(height: 20),
          pw.Text(currencyOf(cur).name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            tile(s.pdfIncome, formatMoney(inc, cur), income),
            pw.SizedBox(width: 8),
            tile(s.pdfExpense, formatMoney(exp, cur), expense),
            pw.SizedBox(width: 8),
            tile(s.pdfNet, formatMoney(inc - exp, cur), inc - exp >= 0 ? income : expense),
          ]),
          if (spend.isNotEmpty) table(s.pdfByCategory, spend, exp, cur),
          if (sources.isNotEmpty) table(s.pdfIncomeSources, sources, inc, cur),
        ];
      }(),
    ],
  ));
  return doc.save();
}
