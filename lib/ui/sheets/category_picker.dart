import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';

/// Full category grid with search; resolves to the picked category id.
Future<String?> showCategoryPicker(
  BuildContext context, {
  String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryPicker(selectedId: selectedId),
  );
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({this.selectedId});

  final String? selectedId;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final media = MediaQuery.of(context);
    final all = context.read<LedgerStore>().categories;
    final q = _q.trim().toLowerCase();
    final cats = q.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(q)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(s.chooseCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            if (all.length > 12)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: appInputDecoration(
                    context,
                    hint: s.categorySearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
            Flexible(
              child: cats.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        s.noCategoryMatches,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.muted),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 88,
                        mainAxisExtent: 84,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: cats.length,
                      itemBuilder: (context, i) {
                        final cat = cats[i];
                        return CategoryTile(
                          key: ValueKey(cat.id),
                          emoji: cat.emoji,
                          name: cat.name,
                          color: Color(cat.color),
                          selected: cat.id == widget.selectedId,
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

/// Emoji + name tile used in the Add sheet strip and the picker grid.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
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
