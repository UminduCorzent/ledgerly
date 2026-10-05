import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/category.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';
import '../widgets/emoji_avatar.dart';
import 'category_editor_sheet.dart';
import 'delete_categories_flow.dart';

/// The active account's categories: search, reorder, multi-select delete.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _searching = false;
  String _query = '';
  List<String>? _order; // non-null while reordering
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final ledger = context.watch<LedgerStore>();
    final account = ledger.activeAccount;
    if (account == null) return const SizedBox.shrink();
    final all = ledger.categoriesFor(account.id);
    final usage = ledger.categoryUsage(account.id);
    _selected.removeWhere((id) => ledger.category(id) == null);

    final PreferredSizeWidget bar;
    if (_order != null) {
      bar = AppTopBar(
        title: s.reorder,
        leading: IconButton(
          tooltip: s.cancel,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() => _order = null),
        ),
        actions: [TextButton(onPressed: _saveOrder, child: Text(s.save))],
      );
    } else if (_selecting) {
      final allSelected = all.every((x) => _selected.contains(x.id));
      bar = AppTopBar(
        title: s.selectedCount(_selected.length),
        leading: IconButton(
          tooltip: s.clearSelection,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(_selected.clear),
        ),
        actions: [
          IconButton(
            tooltip: allSelected ? s.clearSelection : s.selectAll,
            icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
            onPressed: () => setState(() {
              if (allSelected) {
                _selected.clear();
              } else {
                _selected.addAll(all.map((x) => x.id));
              }
            }),
          ),
          IconButton(
            tooltip: s.delete,
            icon: Icon(Icons.delete_outline_rounded, color: c.expense),
            onPressed: () async {
              await runDeleteCategoriesFlow(context, account.id, Set.of(_selected));
              if (mounted) setState(_selected.clear);
            },
          ),
        ],
      );
    } else {
      bar = AppTopBar(
        title: s.categoriesTitle,
        actions: [
          IconButton(
            tooltip: _searching ? s.closeSearch : s.search,
            icon: Icon(_searching ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          if (all.length > 1)
            IconButton(
              tooltip: s.reorder,
              icon: const Icon(Icons.swap_vert_rounded),
              onPressed: () => setState(() => _order = all.map((x) => x.id).toList()),
            ),
          IconButton(
            tooltip: s.addCategory,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showCategoryEditor(context, accountId: account.id),
          ),
        ],
      );
    }

    final Widget body;
    if (_order != null) {
      final order = _order!;
      body = ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        buildDefaultDragHandles: false,
        itemCount: order.length,
        onReorderItem: (from, to) => setState(() {
          final id = order.removeAt(from);
          order.insert(to, id);
        }),
        itemBuilder: (context, i) {
          final cat = ledger.category(order[i])!;
          return Padding(
            key: ValueKey(cat.id),
            padding: const EdgeInsets.only(bottom: 6),
            child: _CategoryRow(
              category: cat,
              usage: usage[cat.id] ?? 0,
              trailing: ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle_rounded, color: c.muted),
                ),
              ),
            ),
          );
        },
      );
    } else {
      final q = _query.trim().toLowerCase();
      final shown = q.isEmpty ? all : all.where((x) => x.name.toLowerCase().contains(q)).toList();
      body = CustomScrollView(
        slivers: [
          if (_searching && !_selecting)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: appInputDecoration(
                    context,
                    hint: s.searchCategories,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
            ),
          if (shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(s.noCategoryMatches, style: TextStyle(color: c.muted))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final cat = shown[i];
                    final selected = _selected.contains(cat.id);
                    return Padding(
                      key: ValueKey(cat.id),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _CategoryRow(
                        category: cat,
                        usage: usage[cat.id] ?? 0,
                        selectionMode: _selecting,
                        selected: selected,
                        onTap: () {
                          if (_selecting) {
                            HapticFeedback.selectionClick();
                            setState(() => selected ? _selected.remove(cat.id) : _selected.add(cat.id));
                          } else {
                            showCategoryEditor(context, accountId: account.id, editing: cat);
                          }
                        },
                        onLongPress: _selecting
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                setState(() => _selected.add(cat.id));
                              },
                      ),
                    );
                  },
                  childCount: shown.length,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final idx = shown.indexWhere((x) => x.id == key.value);
                    return idx < 0 ? null : idx;
                  },
                ),
              ),
            ),
        ],
      );
    }

    return PopScope(
      canPop: !_selecting && _order == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          _selected.clear();
          _order = null;
        });
      },
      child: Scaffold(appBar: bar, body: body),
    );
  }

  Future<void> _saveOrder() async {
    final order = _order;
    if (order == null) return;
    final s = AppStrings.of(context);
    final r = await context.read<LedgerStore>().reorderCategories(order);
    if (!mounted || !r.success) return;
    HapticFeedback.lightImpact();
    setState(() => _order = null);
    showSnack(context, s.categoriesReordered);
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.usage,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.selectionMode = false,
    this.selected = false,
  });

  final Category category;
  final int usage;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    return Material(
      color: selected ? c.primary.withValues(alpha: 0.10) : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? c.primary : c.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? c.primary : c.muted,
                ),
                const SizedBox(width: 10),
              ],
              EmojiAvatar(emoji: category.emoji, color: Color(category.color), size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(s.usageCount(usage), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              trailing ?? (selectionMode ? const SizedBox.shrink() : Icon(Icons.chevron_right_rounded, color: c.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
