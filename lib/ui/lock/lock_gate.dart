import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../state/lock_store.dart';
import 'pin_pad.dart';

/// Root navigator, used to block the Back button while the app is locked.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Sits above the whole app (MaterialApp.builder). While locked it hides the
/// content (kept alive, not rebuilt) and shows the lock screen on top.
///
/// Pages and sheets are deliberately left open: the lock screen covers all of
/// them, and after unlocking you return exactly where you were (e.g. mid-import).
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _wasLocked = false;

  /// Invisible top route while locked, so Back can't pop hidden pages.
  Route<void>? _backBlocker;

  void _syncBackBlocker() {
    // After the frame: on a cold start the Navigator doesn't exist yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = appNavigatorKey.currentState;
      if (nav == null || !mounted) return;
      final stillLocked = context.read<LockStore>().locked;
      if (stillLocked && _backBlocker == null) {
        final route = PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const PopScope(canPop: false, child: SizedBox.shrink()),
        );
        _backBlocker = route;
        nav.push(route);
      } else if (!stillLocked && _backBlocker != null) {
        final route = _backBlocker!;
        _backBlocker = null;
        if (route.isActive) nav.removeRoute(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.select<LockStore, bool>((l) => l.locked);
    if (locked != _wasLocked) _syncBackBlocker();
    _wasLocked = locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: locked, child: TickerMode(enabled: !locked, child: widget.child)),
        if (locked) const _LockScreen(),
      ],
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  String? _error;
  int _errors = 0;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    final lock = context.read<LockStore>();
    if (lock.biometricEnabled) {
      lock.biometricAvailable().then((available) {
        if (!mounted || !available) return;
        setState(() => _bioAvailable = true);
        // Offer biometrics straight away, once.
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
      });
    }
  }

  Future<void> _tryBiometric() async {
    final s = AppStrings.of(context);
    await context.read<LockStore>().unlockWithBiometric(s.biometricReason);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final lock = context.watch<LockStore>();
    final left = lock.lockoutRemaining;
    return Material(
      child: PinBackground(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            PinPad(
              title: s.pinEnterTitle,
              subtitle: s.lockedTitle,
              error: _error == null ? null : '$_error${'​' * (_errors % 2)}',
              lockoutUntil: left == null ? null : DateTime.now().add(left),
              extraKey: _bioAvailable && lock.biometricEnabled
                  ? Semantics(
                      button: true,
                      label: s.useBiometric,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _tryBiometric,
                          child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    )
                  : null,
              onComplete: (pin) async {
                final ok = await lock.unlockWithPin(pin);
                if (!mounted) return ok;
                if (ok) {
                  HapticFeedback.lightImpact();
                } else {
                  setState(() {
                    _error = s.pinWrong;
                    _errors++;
                  });
                }
                return ok;
              },
            ),
          ],
        ),
      ),
    );
  }
}
