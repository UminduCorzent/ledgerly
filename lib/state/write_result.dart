import '../data/change_set.dart';

/// Outcome of a store write. Stores never throw to the UI: on failure they reload
/// from disk and report it, and the caller just checks [success] before
/// showing a success message, playing haptics or closing a sheet.
class WriteResult {
  const WriteResult._(this.success, this.undo, this.error);

  factory WriteResult.ok([ChangeSet? undo]) => WriteResult._(true, undo, null);
  factory WriteResult.fail(Object error) => WriteResult._(false, null, error);

  final bool success;

  /// Applying this with `store.undo` reverses the write exactly.
  final ChangeSet? undo;
  final Object? error;
}
