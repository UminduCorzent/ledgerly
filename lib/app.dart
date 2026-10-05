import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'state/error_reporter.dart';
import 'state/ledger_store.dart';
import 'state/settings_store.dart';
import 'ui/lock/lock_gate.dart';
import 'ui/shell/app_shell.dart';
import 'ui/welcome/welcome_screen.dart';

class LedgerlyApp extends StatelessWidget {
  const LedgerlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsStore, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: AppStrings.current.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      themeAnimationDuration: Motion.standard,
      scaffoldMessengerKey: appMessengerKey,
      navigatorKey: appNavigatorKey,
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
      home: const _Gate(),
    );
  }
}

/// First launch shows Welcome until an account exists.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final hasAccounts = context.select<LedgerStore, bool>((l) => l.hasAccounts);
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.standard),
      child: hasAccounts ? const AppShell() : const WelcomeScreen(),
    );
  }
}
