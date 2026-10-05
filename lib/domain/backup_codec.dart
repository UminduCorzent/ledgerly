import 'dart:convert';

// Full-database backup file format (JSON). The PIN hash and other lock
// settings are never written, and are never read back: a restore always keeps
// this device's own lock settings.

const String kBackupApp = 'ledgerly';
const int kBackupFormatVersion = 1;

/// Settings that belong to this device, not to the data.
bool isDeviceOnlySetting(String key) => key.startsWith('lock_') || key == 'schemaVersion';

class BackupData {
  const BackupData({
    required this.createdAt,
    required this.accounts,
    required this.categories,
    required this.txns,
    required this.settings,
  });

  final DateTime createdAt;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> txns;
  final Map<String, dynamic> settings;

  int get recordCount => accounts.length + categories.length + txns.length;
}

String encodeBackup(BackupData d) => const JsonEncoder.withIndent(' ').convert({
      'app': kBackupApp,
      'formatVersion': kBackupFormatVersion,
      'createdAt': d.createdAt.millisecondsSinceEpoch,
      'accounts': d.accounts,
      'categories': d.categories,
      'txns': d.txns,
      'settings': {
        for (final e in d.settings.entries)
          if (!isDeviceOnlySetting(e.key)) e.key: e.value,
      },
    });

List<Map<String, dynamic>>? _records(Object? v) {
  if (v is! List) return null;
  final out = <Map<String, dynamic>>[];
  for (final item in v) {
    if (item is! Map || item['id'] is! String) return null;
    out.add(Map<String, dynamic>.from(item));
  }
  return out;
}

/// Parses and validates a backup. Returns null if it isn't a Ledgerly backup
/// this version can read.
BackupData? decodeBackup(String text) {
  try {
    final m = jsonDecode(text);
    if (m is! Map || m['app'] != kBackupApp) return null;
    final version = m['formatVersion'];
    if (version is! int || version < 1 || version > kBackupFormatVersion) return null;
    final accounts = _records(m['accounts']);
    final categories = _records(m['categories']);
    final txns = _records(m['txns']);
    final settings = m['settings'];
    if (accounts == null || categories == null || txns == null || settings is! Map) return null;
    if (accounts.isEmpty) return null;
    final created = m['createdAt'];
    return BackupData(
      createdAt: DateTime.fromMillisecondsSinceEpoch(created is int ? created : 0),
      accounts: accounts,
      categories: categories,
      txns: txns,
      settings: {
        for (final e in settings.entries)
          if (!isDeviceOnlySetting(e.key.toString())) e.key.toString(): e.value,
      },
    );
  } catch (_) {
    return null;
  }
}
