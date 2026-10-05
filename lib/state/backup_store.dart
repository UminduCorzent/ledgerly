import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;

import '../data/db.dart';
import '../domain/backup_codec.dart';
import 'error_reporter.dart';
import 'ledger_store.dart';
import 'settings_store.dart';

enum BackupKind { manual, safety }

@immutable
class BackupEntry {
  const BackupEntry({required this.id, required this.createdAt, required this.kind, required this.json});

  final String id;
  final DateTime createdAt;
  final BackupKind kind;
  final String json;

  int get sizeBytes => utf8.encode(json).length;

  String get fileName {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = createdAt;
    return 'ledgerly-backup-${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}.json';
  }
}

enum RestoreOutcome { restored, invalidFile, failedRolledBack }

/// Full-database backups kept on the device, plus restore with a safety backup
/// and automatic rollback. Lock settings are never written to or read from a backup.
class BackupStore extends ChangeNotifier {
  BackupStore(this._db, this._ledger, this._settings);

  final Db _db;
  final LedgerStore _ledger;
  final SettingsStore _settings;

  /// Newest backups kept per kind. Safety backups (made before a restore) have
  /// their own limit, so they never push your own backups out.
  static const int keepManual = 5;
  static const int keepSafety = 3;

  List<BackupEntry> get backups {
    final list = <BackupEntry>[
      for (final v in _db.box(Db.backups).values)
        if (v is Map)
          BackupEntry(
            id: v['id'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch((v['createdAt'] as num).toInt()),
            kind: v['kind'] == 'safety' ? BackupKind.safety : BackupKind.manual,
            json: v['json'] as String,
          ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  String buildJson() => encodeBackup(BackupData(
        createdAt: DateTime.now(),
        accounts: _db.all(Db.accounts).toList(),
        categories: _db.all(Db.categories).toList(),
        txns: _db.all(Db.txns).toList(),
        settings: _db.allSettings(),
      ));

  Future<BackupEntry?> create({BackupKind kind = BackupKind.manual}) async {
    try {
      final now = DateTime.now();
      final entry = BackupEntry(
        id: '${kind.name}_${now.microsecondsSinceEpoch}',
        createdAt: now,
        kind: kind,
        json: buildJson(),
      );
      await _db.box(Db.backups).put(entry.id, {
        'id': entry.id,
        'createdAt': now.millisecondsSinceEpoch,
        'kind': kind.name,
        'json': entry.json,
      });
      await _prune(kind);
      notifyListeners();
      return entry;
    } catch (e) {
      debugPrint('Backup failed: $e');
      ErrorReporter.saveFailed();
      return null;
    }
  }

  Future<void> _prune(BackupKind kind) async {
    final keep = kind == BackupKind.safety ? keepSafety : keepManual;
    final old = backups.where((b) => b.kind == kind).skip(keep).map((b) => b.id).toList();
    if (old.isNotEmpty) await _db.box(Db.backups).deleteAll(old);
  }

  Future<void> delete(String id) async {
    try {
      await _db.box(Db.backups).delete(id);
    } catch (_) {
      ErrorReporter.saveFailed();
    }
    notifyListeners();
  }

  /// Validates [json], saves a safety backup of the current data, replaces
  /// everything, checks the record counts, and rolls back if anything fails.
  Future<RestoreOutcome> restore(String json) async {
    final data = decodeBackup(json);
    if (data == null) return RestoreOutcome.invalidFile;
    final safety = await create(kind: BackupKind.safety);
    if (safety == null) return RestoreOutcome.failedRolledBack;
    try {
      await _apply(data);
      final ok = _db.count(Db.accounts) == data.accounts.length &&
          _db.count(Db.categories) == data.categories.length &&
          _db.count(Db.txns) == data.txns.length;
      if (!ok) throw StateError('record counts differ after restore');
      _reloadAll();
      return RestoreOutcome.restored;
    } catch (e) {
      debugPrint('Restore failed, rolling back: $e');
      final previous = decodeBackup(safety.json);
      if (previous != null) {
        try {
          await _apply(previous);
        } catch (_) {}
      }
      _reloadAll();
      return RestoreOutcome.failedRolledBack;
    }
  }

  Future<void> _apply(BackupData d) => _db.replaceAll(
        accountsData: d.accounts,
        categoriesData: d.categories,
        txnsData: d.txns,
        settingsData: d.settings,
        keepSetting: isDeviceOnlySetting,
      );

  /// Reload every store, so the restored data shows immediately (no restart).
  void _reloadAll() {
    _ledger.load();
    _settings.reload();
    notifyListeners();
  }
}
