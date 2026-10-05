import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/account.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';

/// Confirm → choose what happens to the transactions → delete → Undo.
Future<void> runDeleteAccountFlow(BuildContext context, Account account) async {
  final s = AppStrings.of(context);
  final store = context.read<LedgerStore>();
  if (store.accounts.length <= 1) {
    showSnack(context, s.cannotDeleteLast);
    return;
  }
  final others = store.accounts.where((a) => a.id != account.id).toList();
  final txnCount = store.txnCount(account.id);
  final transferCount = store.transferCount(account.id);

  final choice = await showDialog<_Choice>(
    context: context,
    builder: (_) => _DeleteAccountDialog(
      account: account,
      others: others,
      txnCount: txnCount,
      transferCount: transferCount,
    ),
  );
  if (choice == null || !context.mounted) return;

  final r = await store.deleteAccount(account.id, reassignToId: choice.reassignTo);
  if (!context.mounted || !r.success) return;
  HapticFeedback.mediumImpact();
  final undo = r.undo;
  showSnack(
    context,
    s.accountDeleted,
    onUndo: undo == null ? null : () => store.undo(undo),
  );
}

class _Choice {
  const _Choice(this.reassignTo);

  /// Null = delete the account's transactions.
  final String? reassignTo;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({
    required this.account,
    required this.others,
    required this.txnCount,
    required this.transferCount,
  });

  final Account account;
  final List<Account> others;
  final int txnCount;
  final int transferCount;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _reassign = true;
  late String _target = widget.others.first.id;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final hasTxns = widget.txnCount > 0;

    Widget option(bool value, String label, {Color? color}) {
      final selected = _reassign == value;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _reassign = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? (color ?? c.primary) : c.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(s.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.deleteAccountBody(widget.account.name)),
            if (hasTxns) ...[
              const SizedBox(height: 14),
              Text(s.deleteAccountHasTxns(widget.txnCount), style: TextStyle(color: c.warn, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              option(true, s.reassignTxns),
              if (_reassign)
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 4),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _target,
                    onChanged: (v) => setState(() => _target = v ?? _target),
                    items: [
                      for (final a in widget.others)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.emoji} ${a.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              option(false, s.deleteTxns, color: c.expense),
              if (!_reassign && widget.transferCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 34, top: 2),
                  child: Text(
                    s.deleteAccountTransfersNote(widget.transferCount),
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ),
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
          onPressed: () => Navigator.pop(
            context,
            _Choice(hasTxns && _reassign ? _target : null),
          ),
          child: Text(s.delete),
        ),
      ],
    );
  }
}
