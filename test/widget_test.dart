import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/theme/app_theme.dart';
import 'package:ledgerly/models/txn.dart';
import 'package:ledgerly/ui/widgets/app_keypad.dart';
import 'package:ledgerly/ui/widgets/donut_chart.dart';
import 'package:ledgerly/ui/widgets/segmented.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  testWidgets('keypad reports keys and save', (tester) async {
    final keys = <String>[];
    var saved = false;
    await tester.pumpWidget(_host(AppKeypad(
      onKey: keys.add,
      onClear: () {},
      onSave: () => saved = true,
      saveLabel: 'Save',
      saveColor: AppTheme.light.colorScheme.error,
    )));
    await tester.tap(find.text('7'));
    await tester.tap(find.text('.'));
    await tester.tap(find.text('Save'));
    expect(keys, ['7', '.']);
    expect(saved, isTrue);
  });

  testWidgets('segmented control switches value', (tester) async {
    TxnType? picked;
    await tester.pumpWidget(_host(Segmented<TxnType>(
      values: const [TxnType.expense, TxnType.income],
      labels: const ['Expense', 'Income'],
      selected: TxnType.expense,
      onChanged: (v) => picked = v,
    )));
    await tester.tap(find.text('Income'));
    expect(picked, TxnType.income);
  });

  testWidgets('donut renders in dark theme without errors', (tester) async {
    await tester.pumpWidget(_host(
      const Center(
        child: DonutChart(
          slices: [
            DonutSlice('a', 60, Color(0xFFF97316)),
            DonutSlice('b', 40, Color(0xFF3B82F6)),
          ],
          trackColor: Color(0xFF1A2538),
        ),
      ),
      theme: AppTheme.dark,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(DonutChart), findsOneWidget);
  });
}
