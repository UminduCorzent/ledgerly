import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/seeds.dart';
import '../../models/category.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';
import 'delete_categories_flow.dart';

Future<void> showCategoryEditor(
  BuildContext context, {
  Category? editing,
}) async {
  final deleteRequested = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditor(editing: editing),
  );
  // Delete runs after the sheet closes, so its dialog and Undo snackbar sit on the screen.
  if (deleteRequested == true && editing != null && context.mounted) {
    await runDeleteCategoriesFlow(context, {editing.id});
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.editing});

  final Category? editing;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.editing?.name ?? '');
  late String _emoji = widget.editing?.emoji ?? kCategoryEmoji.first;
  late int _color = widget.editing?.color ?? kPalette[8];
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
    if (store.isCategoryNameTaken(name, exceptId: widget.editing?.id)) {
      setState(() => _error = s.categoryNameTaken);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final e = widget.editing;
    final r = e == null
        ? await store.createCategory(name: name, emoji: _emoji, color: _color)
        : await store.updateCategory(e.copyWith(name: name, emoji: _emoji, color: _color));
    if (!mounted) return;
    setState(() => _saving = false);
    if (!r.success) return;
    HapticFeedback.lightImpact();
    nav.pop(false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e == null ? s.categoryAdded : s.categoryUpdated)));
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
                      widget.editing == null ? s.addCategory : s.editCategory,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                        decoration: BoxDecoration(
                          color: c.tinted(color),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EmojiAvatar(emoji: _emoji, color: color, size: 36),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _name.text.trim().isEmpty ? s.categoryNameHint : _name.text.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    label(s.categoryName),
                    TextField(
                      controller: _name,
                      autofocus: widget.editing == null,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      onChanged: (_) => setState(() => _error = null),
                      decoration: appInputDecoration(context, hint: s.categoryNameHint, errorText: _error),
                    ),
                    label(s.categoryIcon),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in kCategoryEmoji)
                          Material(
                            color: e == _emoji ? c.tinted(color) : c.surface2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: e == _emoji ? color : Colors.transparent, width: 2),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() => _emoji = e),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(child: Text(e, style: const TextStyle(fontSize: 21))),
                              ),
                            ),
                          ),
                      ],
                    ),
                    label(s.categoryColor),
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
                                border: Border.all(color: col == _color ? c.text : Colors.transparent, width: 3),
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
              child: Row(
                children: [
                  if (widget.editing != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.expense,
                          side: BorderSide(color: c.expense, width: 1.5),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(s.delete),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(widget.editing == null ? s.add : s.save),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
