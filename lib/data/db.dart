import 'package:hive_ce_flutter/hive_flutter.dart';

import 'change_set.dart';

/// Local storage. Records are plain maps in Hive boxes (no code generation),
/// which also makes Hive work in the browser (IndexedDB) for the web preview.
class Db {
  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String txns = 'txns';
  static const String settings = 'settings';

  static const List<String> recordBoxes = [accounts, categories, txns];

  /// Bump when stored data needs reshaping, and add a step to [_migrate].
  static const int schemaVersion = 1;

  final Map<String, Box<dynamic>> _boxes = {};

  Box<dynamic> box(String name) => _boxes[name]!;

  Future<void> init() async {
    await Hive.initFlutter('ledgerly');
    for (final name in [...recordBoxes, settings]) {
      _boxes[name] = await Hive.openBox<dynamic>(name);
    }
    await _migrate();
  }

  Future<void> _migrate() async {
    final s = box(settings);
    final from = (s.get('schemaVersion') as num?)?.toInt() ?? 0;
    if (from == schemaVersion) return;
    // v0 → v1: first install, nothing to reshape.
    await s.put('schemaVersion', schemaVersion);
  }

  static Map<String, dynamic> _cast(dynamic v) =>
      Map<String, dynamic>.from(v as Map);

  Iterable<Map<String, dynamic>> all(String boxName) =>
      box(boxName).values.map(_cast);

  Map<String, dynamic>? read(String boxName, String id) {
    final v = box(boxName).get(id);
    return v == null ? null : _cast(v);
  }

  /// Writes [cs] and returns its inverse (for Undo).
  Future<ChangeSet> apply(ChangeSet cs) async {
    final inverse = ChangeSet();
    for (final entry in cs.ops.entries) {
      for (final id in entry.value.keys) {
        final before = read(entry.key, id);
        if (before == null) {
          inverse.delete(entry.key, id);
        } else {
          inverse.put(entry.key, id, before);
        }
      }
    }
    for (final entry in cs.ops.entries) {
      final b = box(entry.key);
      final puts = <String, Map<String, dynamic>>{};
      final deletes = <String>[];
      entry.value.forEach((id, value) {
        if (value == null) {
          deletes.add(id);
        } else {
          puts[id] = value;
        }
      });
      if (puts.isNotEmpty) await b.putAll(puts);
      if (deletes.isNotEmpty) await b.deleteAll(deletes);
    }
    return inverse;
  }

  T? setting<T>(String key) => box(settings).get(key) as T?;

  Future<void> setSetting(String key, Object? value) =>
      value == null ? box(settings).delete(key) : box(settings).put(key, value);
}
