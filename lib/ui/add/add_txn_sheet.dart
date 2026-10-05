import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../domain/amount_input.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../models/txn.dart';
import '../../state/ledger_store.dart';
import '../sheets/account_sheets.dart';
import '../widgets/app_keypad.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';
import '../widgets/segmented.dart';

/// Opens the keypad-first Add sheet, or the Edit sheet when [editing] is given
/// (either leg of a transfer opens the whole transfer).
Future<void> showAddTxnSheet(BuildContext context, {Txn? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddTxnSheet(editing: editing),
  );
}

class AddTxnSheet extends StatefulWidget {
  const AddTxnSheet({super.key, this.editing});

  final Txn? editing;

  @override
  State<AddTxnSheet> createState() => _AddTxnSheetState();
}

class _AddTxnSheetState extends State<AddTxnSheet> with SingleTickerProviderStateMixin {
  late final LedgerStore _store = context.read<LedgerStore>();

  late TxnType _type;
  late String _accountId;
  String? _toId;
  String _amount = '';
  String _received = '';

  /// Which amount the keypad edits for a cross-currency transfer: 0 sent, 1 received.
  int _target = 0;
  String? _categoryId;
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final FocusNode _descFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  bool _descEdited = false;
  bool _typing = false;
  late DateTime _date;
  bool _excluded = false;
  bool _more = false;

  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  bool get _isEdit => widget.editing != null;
  bool get _isTransfer => _type == TxnType.transfer;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) {
      final active = _store.activeAccount!;
      _type = TxnType.expense;
      _accountId = active.id;
      _toId = _firstOther(active.id);
      _categoryId = _store.defaultCategoryId(active.id, TxnType.expense);
      _desc.text = _store.category(_categoryId)?.name ?? '';
      _date = DateTime.now();
    } else if (e.isTransfer) {
      final other = _store.counterpart(e);
      final outLeg = e.direction == TransferDirection.outgoing ? e : other;
      final inLeg = e.direction == TransferDirection.outgoing ? other : e;
      _type = TxnType.transfer;
      _accountId = outLeg?.accountId ?? e.accountId;
      _toId = inLeg?.accountId ?? e.counterAccountId;
      _amount = amountToInput(outLeg?.amount ?? e.amount);
      _received = amountToInput(inLeg?.amount ?? e.amount);
      _desc.text = e.description;
      _descEdited = true;
      _date = e.date;
    } else {
      _type = e.type;
      _accountId = e.accountId;
      _toId = _firstOther(e.accountId);
      _amount = amountToInput(e.amount);
      _categoryId = e.categoryId;
      _desc.text = e.description;
      _descEdited = true;
      _excluded = e.excluded;
      _date = e.date;
    }
    _notes.text = e?.notes ?? '';
    _more = _notes.text.isNotEmpty || _excluded;
    _descFocus.addListener(_onFocus);
    _notesFocus.addListener(_onFocus);
  }

  void _onFocus() {
    final typing = _descFocus.hasFocus || _notesFocus.hasFocus;
    if (typing != _typing) setState(() => _typing = typing);
  }

  @override
  void dispose() {
    _shake.dispose();
    _desc.dispose();
    _notes.dispose();
    _descFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String? _firstOther(String id) {
    for (final a in _store.accounts) {
      if (a.id != id) return a.id;
    }
    return null;
  }

  Account get _from => _store.account(_accountId)!;
  Account? get _to => _store.account(_toId);
  bool get _crossCurrency => _isTransfer && _to != null && _to!.currency != _from.currency;

  Color _typeColor(AppColors c) => switch (_type) {
        TxnType.income => c.income,
        TxnType.expense => c.expense,
        TxnType.transfer => c.transfer,
      };

  // ---------------------------------------------------------------- actions

  void _setType(TxnType t) {
    setState(() {
      _type = t;
      _target = 0;
      if (t == TxnType.transfer) {
        if (_toId == null || _toId == _accountId) _toId = _firstOther(_accountId);
        if (!_descEdited) _desc.text = '';
      } else {
        final cat = _store.category(_categoryId);
        if (!_descEdited || cat == null || cat.accountId != _accountId) {
          _categoryId = _store.defaultCategoryId(_accountId, t);
        }
        if (!_descEdited) _desc.text = _store.category(_categoryId)?.name ?? '';
      }
    });
  }

  void _onKey(String k) {
    setState(() {
      if (_crossCurrency && _target == 1) {
        _received = applyAmountKey(_received, k, decimals: currencyOf(_to!.currency).decimals);
      } else {
        _amount = applyAmountKey(_amount, k, decimals: currencyOf(_from.currency).decimals);
      }
    });
  }

  void _clearAmount() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_crossCurrency && _target == 1) {
        _received = '';
      } else {
        _amount = '';
      }
    });
  }

  Future<void> _pickFrom() async {
    final s = AppStrings.of(context);
    final id = await showAccountPicker(
      context,
      title: _isTransfer ? s.fromAccount : s.chooseAccount,
      selectedId: _accountId,
    );
    if (!mounted || id == null || id == _accountId) return;
    setState(() {
      _accountId = id;
      if (_toId == id) _toId = _firstOther(id);
      final cat = _store.category(_categoryId);
      if (cat == null || cat.accountId != id) {
        _categoryId = _store.defaultCategoryId(id, _isTransfer ? TxnType.expense : _type);
        if (!_descEdited && !_isTransfer) _desc.text = _store.category(_categoryId)?.name ?? '';
      }
    });
  }

  Future<void> _pickTo() async {
    final id = await showAccountPicker(
      context,
      title: AppStrings.of(context).toAccount,
      selectedId: _toId,
      excludeId: _accountId,
    );
    if (!mounted || id == null) return;
    setState(() => _toId = id);
  }

  void _swap() {
    final to = _toId;
    if (to == null) return;
    setState(() {
      _toId = _accountId;
      _accountId = to;
      if (_received.isNotEmpty) {
        final a = _amount;
        _amount = _received;
        _received = a;
      }
      _target = 0;
    });
  }

  void _selectCategory(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _categoryId = id;
      if (!_descEdited) _desc.text = _store.category(id)?.name ?? '';
    });
  }

  Future<void> _allCategories() async {
    final cats = _store.categoriesFor(_accountId);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _CategoryGridSheet(categories: cats, selectedId: _categoryId),
    );
    if (!mounted || picked == null) return;
    _selectCategory(picked);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
  }

  void _shakeAmount() {
    HapticFeedback.mediumImpact();
    _shake.forward(from: 0);
  }

  Future<void> _save() async {
    final s = AppStrings.of(context);
    final amount = parseAmount(_amount);
    if (amount <= 0) {
      setState(() => _target = 0);
      _shakeAmount();
      return;
    }
    double? received;
    if (_isTransfer) {
      if (_store.accounts.length < 2) {
        showSnack(context, s.needSecondAccount);
        return;
      }
      if (_toId == null || _toId == _accountId) {
        showSnack(context, s.pickTwoAccounts);
        return;
      }
      received = _crossCurrency ? parseAmount(_received) : amount;
      if (received <= 0) {
        setState(() => _target = 1);
        _shakeAmount();
        return;
      }
    } else if (_store.category(_categoryId) == null) {
      showSnack(context, s.pickCategory);
      return;
    }

    var description = _desc.text.trim();
    if (description.isEmpty) {
      description = _isTransfer
          ? s.transferDefaultDescription
          : (_store.category(_categoryId)?.name ?? '');
    }
    final notes = _notes.text.trim();
    final draft = TxnDraft(
      type: _type,
      accountId: _accountId,
      toAccountId: _isTransfer ? _toId : null,
      amount: amount,
      received: received,
      categoryId: _isTransfer ? null : _categoryId,
      description: description,
      date: _date,
      notes: notes.isEmpty ? null : notes,
      excluded: !_isTransfer && _excluded,
    );
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final r = await _store.saveDraft(draft, editing: widget.editing);
    if (!mounted || !r.success) return;
    HapticFeedback.lightImpact();
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_isEdit ? s.transactionUpdated : s.transactionAdded)));
  }

  Future<void> _delete() async {
    final e = widget.editing;
    if (e == null) return;
    final s = AppStrings.of(context);
    final ok = await confirmDestructive(
      context,
      title: s.deleteTxnTitle,
      body: e.isTransfer ? s.deleteTransferBody : s.deleteTxnBody,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final r = await _store.deleteTxn(e.id);
    if (!mounted || !r.success) return;
    HapticFeedback.mediumImpact();
    nav.pop();
    final undo = r.undo;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.transactionDeleted),
        action: undo == null
            ? null
            : SnackBarAction(label: s.undo, onPressed: () => _store.undo(undo)),
      ));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    // Watch so the category list refreshes if categories change underneath.
    context.watch<LedgerStore>();
    final s = AppStrings.of(context);
    final c = context.colors;
    final media = MediaQuery.of(context);
    final typeColor = _typeColor(c);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? s.editTitle : s.addTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_isEdit)
                    IconButton(
                      tooltip: s.delete,
                      onPressed: _delete,
                      icon: Icon(Icons.delete_outline_rounded, color: c.expense),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Segmented<TxnType>(
                      values: const [TxnType.expense, TxnType.income, TxnType.transfer],
                      labels: [s.typeExpense, s.typeIncome, s.typeTransfer],
                      selected: _type,
                      selectedColors: [c.expense, c.income, c.transfer],
                      onChanged: _setType,
                    ),
                    const SizedBox(height: 10),
                    _buildAmounts(s, c, typeColor),
                    const SizedBox(height: 8),
                    _buildAccounts(s, c),
                    if (!_isTransfer) ...[
                      const SizedBox(height: 10),
                      _buildCategories(s, c),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _desc,
                      focusNode: _descFocus,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [LengthLimitingTextInputFormatter(80)],
                      onChanged: (_) => _descEdited = true,
                      onSubmitted: (_) => _descFocus.unfocus(),
                      decoration: appInputDecoration(
                        context,
                        hint: _isTransfer ? s.transferNoteHint : s.descriptionHint,
                        prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MetaChip(
                            icon: Icons.event_rounded,
                            label: '${dayLabel(_date, s)} · ${timeLabel(_date)}',
                            onTap: _pickDateTime,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: _more ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          label: s.more,
                          onTap: () => setState(() => _more = !_more),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: Motion.of(context, Motion.standard),
                      curve: Motion.enter,
                      alignment: Alignment.topCenter,
                      child: _more ? _buildMore(s, c) : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
            if (!_typing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: AppKeypad(
                  onKey: _onKey,
                  onClear: _clearAmount,
                  onSave: _save,
                  saveLabel: _isEdit ? s.update : s.save,
                  saveColor: typeColor,
                  allowDecimal: currencyOf(
                        _crossCurrency && _target == 1 ? _to!.currency : _from.currency,
                      ).decimals >
                      0,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => FocusScope.of(context).unfocus(),
                    child: Text(s.done),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmounts(AppStrings s, AppColors c, Color typeColor) {
    final shaking = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: _crossCurrency
          ? Row(
              children: [
                Expanded(
                  child: _AmountBox(
                    label: '${s.amountSent} · ${_from.currency}',
                    value: _amount,
                    color: typeColor,
                    active: _target == 0,
                    compact: true,
                    onTap: () => setState(() => _target = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AmountBox(
                    label: '${s.amountReceived} · ${_to!.currency}',
                    value: _received,
                    color: typeColor,
                    active: _target == 1,
                    compact: true,
                    onTap: () => setState(() => _target = 1),
                  ),
                ),
              ],
            )
          : _AmountBox(
              label: _from.currency,
              value: _amount,
              color: typeColor,
              active: false,
            ),
    );
    return shaking;
  }

  Widget _buildAccounts(AppStrings s, AppColors c) {
    if (!_isTransfer) {
      if (_store.accounts.length < 2) return const SizedBox.shrink();
      return _AccountButton(account: _from, onTap: _pickFrom);
    }
    if (_store.accounts.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(s.needSecondAccount, textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
      );
    }
    return Row(
      children: [
        Expanded(child: _AccountButton(account: _from, onTap: _pickFrom, label: s.fromAccount)),
        IconButton(
          tooltip: s.swapAccounts,
          onPressed: _swap,
          icon: Icon(Icons.swap_horiz_rounded, color: c.transfer),
        ),
        Expanded(
          child: _AccountButton(account: _to, onTap: _pickTo, label: s.toAccount),
        ),
      ],
    );
  }

  Widget _buildCategories(AppStrings s, AppColors c) {
    final cats = _store.categoriesFor(_accountId);
    // Two rows that scroll sideways; the last tile opens the full grid.
    return SizedBox(
      height: 168,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 6,
          crossAxisSpacing: 8,
          mainAxisExtent: 74,
        ),
        itemCount: cats.length + 1,
        itemBuilder: (context, i) {
          if (i == cats.length) {
            return _CategoryTile(
              key: const ValueKey('more'),
              emoji: '⋯',
              name: s.more,
              color: c.muted,
              selected: false,
              onTap: _allCategories,
            );
          }
          final cat = cats[i];
          return _CategoryTile(
            key: ValueKey(cat.id),
            emoji: cat.emoji,
            name: cat.name,
            color: Color(cat.color),
            selected: cat.id == _categoryId,
            onTap: () => _selectCategory(cat.id),
          );
        },
      ),
    );
  }

  Widget _buildMore(AppStrings s, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _notes,
            focusNode: _notesFocus,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            decoration: appInputDecoration(
              context,
              hint: s.notesHint,
              prefixIcon: const Icon(Icons.notes_rounded, size: 20),
            ),
          ),
          if (!_isTransfer)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.excludeTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(s.excludeBody, style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _excluded,
                    onChanged: (v) => setState(() => _excluded = v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.label,
    required this.value,
    required this.color,
    required this.active,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final bool active;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: active ? c.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: c.muted,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayAmount(value),
                  style: TextStyle(
                    fontSize: compact ? 28 : 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.15,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.account, required this.onTap, this.label});

  final Account? account;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = account;
    return Material(
      color: c.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              if (a != null) EmojiAvatar(emoji: a.emoji, color: Color(a.color), size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null)
                      Text(label!, style: TextStyle(fontSize: 11, color: c.muted, fontWeight: FontWeight.w600)),
                    Text(
                      a?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.emoji,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.primary.withValues(alpha: 0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? c.primary : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmojiAvatar(emoji: emoji, color: color, size: 40),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGridSheet extends StatelessWidget {
  const _CategoryGridSheet({required this.categories, required this.selectedId});

  final List<Category> categories;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(s.chooseCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 88,
                  mainAxisExtent: 84,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  return _CategoryTile(
                    key: ValueKey(cat.id),
                    emoji: cat.emoji,
                    name: cat.name,
                    color: Color(cat.color),
                    selected: cat.id == selectedId,
                    onTap: () => Navigator.pop(context, cat.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
