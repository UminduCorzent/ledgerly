import 'package:flutter/material.dart';

import '../data/db.dart';
import 'error_reporter.dart';

/// App-wide settings (apply to every account).
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._db);

  final Db _db;

  static const String _kTheme = 'themeMode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void load() {
    _themeMode = switch (_db.setting<String>(_kTheme)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Re-reads settings (after a restore) and updates the UI.
  void reload() {
    load();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _db.setSetting(_kTheme, mode.name);
    } catch (_) {
      load();
      notifyListeners();
      ErrorReporter.saveFailed();
    }
  }
}
