/// A batch of record writes across boxes: `box → id → value` (a null value deletes).
///
/// `Db.apply` returns the inverse ChangeSet (the previous value of every touched
/// record), and applying that inverse is exactly what Undo does. Every write in the app goes
/// through this, so no delete can lack an Undo.
class ChangeSet {
  ChangeSet();

  final Map<String, Map<String, Map<String, dynamic>?>> ops = {};

  void put(String box, String id, Map<String, dynamic> value) =>
      (ops[box] ??= {})[id] = value;

  void delete(String box, String id) => (ops[box] ??= {})[id] = null;

  bool get isEmpty => ops.values.every((m) => m.isEmpty);

  int get length => ops.values.fold(0, (n, m) => n + m.length);
}
