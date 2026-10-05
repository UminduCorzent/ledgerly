import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/category.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';

/// Confirm → move or delete the linked transactions → delete → Undo.
Future<void> runDeleteCategoriesFlow(
  BuildContext context,
  String accountId,
  Set<String> ids,
) async {
  if (ids.isEmpty) return;
  final s = AppStrings.of(context);
  final store = context.read<LedgerStore>();
  final all = store.categoriesFor(accountId);
  final remaining = all.where((c) => !ids.contains(c.id)).toList();
  if (remaining.isEmpty) {
    showSnack(context, s.keepOneCategory);
    return;
  }
  final usage = store.categoryUsage(accountId);
  final linked = ids.fold<int>(0, (n, id) => n + (usage[id] ?? 0));

  final choice = await showDialog<_Choice>(
    context: context,
    builder: (_) => _DeleteDialog(count: ids.length, linked: linked, targets: remaining),
  );
  if (choice == null || !context.mounted) return;

  final r = await store.deleteCategories(ids, reassignToId: choice.moveTo);
  if (!context.mounted || !r.success) return;
  HapticFeedback.mediumImpact();
  final undo = r.undo;
  showSnack(
    context,
    s.categoriesDeleted(ids.length),
    onUndo: undo == null ? null : () => store.undo(undo),
  );
}

class _Choice {
  const _Choice(this.moveTo);

  /// Null = delete the linked transactions.
  final String? moveTo;
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.count, required this.linked, required this.targets});

  final int count;
  final int linked;
  final List<Category> targets;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _move = true;
  late String _target = widget.targets.first.id;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    Widget option(bool value, String label, {Color? color}) {
      final selected = _move == value;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _move = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? (color ?? c.primary) : c.muted,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(s.deleteCategoriesTitle(widget.count)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.deleteCategoriesBody),
            if (widget.linked > 0) ...[
              const SizedBox(height: 14),
              Text(s.categoryHasTxns(widget.linked), style: TextStyle(color: c.warn, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              option(true, s.moveToCategory),
              if (_move)
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 4),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _target,
                    onChanged: (v) => setState(() => _target = v ?? _target),
                    items: [
                      for (final t in widget.targets)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.emoji} ${t.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              option(false, s.deleteTheirTxns, color: c.expense),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.expense,
            foregroundColor: Colors.white,
            minimumSize: const Size(88, 44),
          ),
          onPressed: () => Navigator.pop(context, _Choice(widget.linked > 0 && _move ? _target : null)),
          child: Text(s.delete),
        ),
      ],
    );
  }
}
