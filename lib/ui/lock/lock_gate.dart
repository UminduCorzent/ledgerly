import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../state/lock_store.dart';
import 'pin_pad.dart';

/// Root navigator, so locking can close any open sheet or page underneath.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Sits above the whole app (MaterialApp.builder). While locked it hides the
/// content (kept alive, not rebuilt) and shows the lock screen on top.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _wasLocked = false;

  @override
  Widget build(BuildContext context) {
    final locked = context.select<LockStore, bool>((l) => l.locked);
    if (locked && !_wasLocked) {
      // Close sheets/pages under the lock so nothing sensitive stays open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      });
    }
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
