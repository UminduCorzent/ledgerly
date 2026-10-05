import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/motion.dart';
import '../add/add_txn_sheet.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';

/// Lets any screen switch tabs (e.g. Home → Transactions).
class ShellNav extends InheritedWidget {
  const ShellNav({super.key, required this.goTo, required super.child});

  final ValueChanged<int> goTo;

  static ShellNav? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNav>();

  @override
  bool updateShouldNotify(ShellNav oldWidget) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const int home = 0;
  static const int transactions = 1;
  static const int settings = 2;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = AppShell.home;

  // Tabs are built the first time they're opened, then kept alive.
  final Set<int> _built = {AppShell.home};
  bool _fabExtended = true;

  void _goTo(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _built.add(i);
      _fabExtended = true;
    });
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse && _fabExtended) {
      setState(() => _fabExtended = false);
    } else if (n.direction == ScrollDirection.forward && !_fabExtended) {
      setState(() => _fabExtended = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    const pages = [HomeScreen(), TransactionsScreen(), SettingsScreen()];
    return ShellNav(
      goTo: _goTo,
      child: Scaffold(
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < pages.length; i++)
                _TabPage(
                  active: i == _index,
                  child: _built.contains(i) ? pages[i] : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        floatingActionButton: _index == AppShell.settings
            ? null
            : FloatingActionButton.extended(
                onPressed: () => showAddTxnSheet(context),
                isExtended: _fabExtended,
                icon: const Icon(Icons.add_rounded, size: 26),
                label: Text(s.add),
                tooltip: s.addTitle,
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: s.tabHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: s.tabTransactions,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: s.tabSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab's state while hidden and fades it in (240 ms) when it becomes active.
class _TabPage extends StatefulWidget {
  const _TabPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.standard,
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _opacity = CurvedAnimation(parent: _c, curve: Motion.enter);

  @override
  void didUpdateWidget(_TabPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (Motion.reduced(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        child: FadeTransition(
          opacity: _opacity,
          child: widget.child,
        ),
      ),
    );
  }
}
