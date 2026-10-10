// Folds per-account categories (Ledgerly ≤ 1.1, and backups made by it) into
// one app-wide list. Pure Dart on raw stored maps, so the same step serves the
// on-device schema migration and Restore of an older backup.
//
// * Categories with the same name (trimmed, any case) become one.
// * The survivor is the first in (account order, category order): its emoji
//   and colour win. Survivors are renumbered 0..n in that order.
// * Transactions, per-account default categories (`defaultCat_<type>_<acc>`)
//   and payday categories (`cycle_<acc>.anchorCategoryIds`) follow the merge.
// * Idempotent: already-merged data comes back with [MergeResult.changed] false.

class MergeResult {
  const MergeResult({
    required this.categories,
    required this.removedIds,
    required this.changedTxns,
    required this.changedSettings,
    required this.changed,
  });

  /// Every surviving category, in display order, without `accountId`.
  final List<Map<String, dynamic>> categories;

  /// Categories merged into a survivor.
  final Set<String> removedIds;

  /// Only the transactions whose category changed (by id).
  final Map<String, Map<String, dynamic>> changedTxns;

  /// Only the settings whose value changed.
  final Map<String, dynamic> changedSettings;

  final bool changed;

  /// [txns] with [changedTxns] applied.
  List<Map<String, dynamic>> applyToTxns(List<Map<String, dynamic>> txns) => [
        for (final t in txns) changedTxns[t['id']] ?? t,
      ];
}

MergeResult mergeCategoriesAcrossAccounts({
  required List<Map<String, dynamic>> accounts,
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> txns,
  required Map<String, dynamic> settings,
}) {
  const unknown = 1 << 30;
  final accOrder = <String, int>{
    for (final a in accounts) a['id'] as String: (a['sortOrder'] as num?)?.toInt() ?? 0,
  };
  int order(Map<String, dynamic> c) => (c['sortOrder'] as num?)?.toInt() ?? 0;

  final sorted = List<Map<String, dynamic>>.of(categories)
    ..sort((a, b) {
      final x = (accOrder[a['accountId']] ?? unknown).compareTo(accOrder[b['accountId']] ?? unknown);
      if (x != 0) return x;
      final y = order(a).compareTo(order(b));
      if (y != 0) return y;
      return (a['id'] as String).compareTo(b['id'] as String);
    });

  var changed = false;
  final byName = <String, String>{};
  final idMap = <String, String>{};
  final survivors = <Map<String, dynamic>>[];
  final removed = <String>{};
  for (final c in sorted) {
    final id = c['id'] as String;
    final key = ((c['name'] as String?) ?? '').trim().toLowerCase();
    final hit = byName[key];
    if (hit != null) {
      idMap[id] = hit;
      removed.add(id);
      changed = true;
      continue;
    }
    byName[key] = id;
    final copy = Map<String, dynamic>.of(c)..remove('accountId');
    copy['sortOrder'] = survivors.length;
    if (c.containsKey('accountId') || order(c) != survivors.length) changed = true;
    survivors.add(copy);
  }

  final changedTxns = <String, Map<String, dynamic>>{};
  for (final t in txns) {
    final to = idMap[t['categoryId']];
    if (to != null) changedTxns[t['id'] as String] = Map<String, dynamic>.of(t)..['categoryId'] = to;
  }

  final changedSettings = <String, dynamic>{};
  settings.forEach((key, value) {
    if (key.startsWith('defaultCat_') && value is String && idMap.containsKey(value)) {
      changedSettings[key] = idMap[value];
    } else if (key.startsWith('cycle_') && value is Map) {
      final ids = value['anchorCategoryIds'];
      if (ids is List && ids.any(idMap.containsKey)) {
        final next = <String>{for (final v in ids) idMap[v] ?? v as String}.toList();
        changedSettings[key] = Map<String, dynamic>.from(value)..['anchorCategoryIds'] = next;
      }
    }
  });

  return MergeResult(
    categories: survivors,
    removedIds: removed,
    changedTxns: changedTxns,
    changedSettings: changedSettings,
    changed: changed,
  );
}
