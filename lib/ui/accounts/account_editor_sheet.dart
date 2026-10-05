import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/seeds.dart';
import '../../models/account.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';

Future<void> showAccountEditor(BuildContext context, {Account? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AccountEditor(editing: editing),
  );
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({this.editing});

  final Account? editing;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.editing?.name ?? '');
  late AccountType _type = widget.editing?.type ?? AccountType.other;
  late String _currency = widget.editing?.currency ?? kDefaultCurrency;
  late String _emoji = widget.editing?.emoji ?? kAccountEmoji.first;
  late int _color = widget.editing?.color ?? kPalette.first;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppStrings.of(context);
    final store = context.read<LedgerStore>();
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = s.nameTooShort);
      return;
    }
    if (store.isAccountNameTaken(name, exceptId: widget.editing?.id)) {
      setState(() => _error = s.nameTaken);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final e = widget.editing;
    final r = e == null
        ? await store.createAccount(
            name: name,
            currency: _currency,
            emoji: _emoji,
            color: _color,
            type: _type,
          )
        : await store.updateAccount(
            e.copyWith(name: name, currency: _currency, emoji: _emoji, color: _color, type: _type),
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!r.success) return;
    HapticFeedback.lightImpact();
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e == null ? s.accountAdded : s.accountUpdated)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final color = Color(_color);
    final media = MediaQuery.of(context);

    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: c.muted, fontSize: 13)),
        );

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
                    Text(
                      widget.editing == null ? s.addAccount : s.editAccount,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    // Live preview in the account's own colour.
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.tinted(color),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          EmojiAvatar(emoji: _emoji, color: color, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name.text.trim().isEmpty ? s.accountNameHint : _name.text.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                Text(
                                  '${s.accountTypeLabel(_type.name)} · $_currency',
                                  style: TextStyle(color: c.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    label(s.accountName),
                    TextField(
                      controller: _name,
                      autofocus: widget.editing == null,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      onChanged: (_) => setState(() => _error = null),
                      decoration: appInputDecoration(context, hint: s.accountNameHint, errorText: _error),
                    ),
                    label(s.accountType),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in AccountType.values)
                          ChoiceChip(
                            label: Text(s.accountTypeLabel(t.name)),
                            selected: t == _type,
                            onSelected: (_) => setState(() => _type = t),
                          ),
                      ],
                    ),
                    label(s.accountCurrency),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cur in kCurrencies)
                          ChoiceChip(
                            label: Text('${cur.symbol}  ${cur.code}'),
                            selected: cur.code == _currency,
                            onSelected: (_) => setState(() => _currency = cur.code),
                          ),
                      ],
                    ),
                    label(s.accountIcon),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in kAccountEmoji)
                          _Pickable(
                            selected: e == _emoji,
                            color: color,
                            onTap: () => setState(() => _emoji = e),
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                      ],
                    ),
                    label(s.accountColor),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final col in kPalette)
                          GestureDetector(
                            onTap: () => setState(() => _color = col),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Color(col),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: col == _color ? c.text : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: col == _color
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(widget.editing == null ? s.add : s.save),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pickable extends StatelessWidget {
  const _Pickable({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.tinted(color) : c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? color : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Center(child: child)),
      ),
    );
  }
}
