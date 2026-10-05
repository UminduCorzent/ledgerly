import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/db.dart';
import 'state/backup_store.dart';
import 'state/ledger_store.dart';
import 'state/lock_store.dart';
import 'state/settings_store.dart';
import 'state/txn_filter_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _boot();
}

Future<void> _boot() async {
  final db = Db();
  try {
    await db.init();
  } catch (e) {
    debugPrint('Storage init failed: $e');
    runApp(_StartupError(onRetry: _boot));
    return;
  }
  final settings = SettingsStore(db)..load();
  final ledger = LedgerStore(db)..load();
  final filters = TxnFilterStore(ledger, db);
  final lock = LockStore(db)..load();
  final backups = BackupStore(db, ledger, settings);
  WidgetsBinding.instance.addObserver(lock);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<LockStore>.value(value: lock),
        ChangeNotifierProvider<LedgerStore>.value(value: ledger),
        ChangeNotifierProvider<TxnFilterStore>.value(value: filters),
        ChangeNotifierProvider<BackupStore>.value(value: backups),
      ],
      child: const LedgerlyApp(),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    const s = AppStrings.current;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  s.startFailedTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(s.startFailedBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: Text(s.retry)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
