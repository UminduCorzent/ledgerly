import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings/app_strings.dart';
import '../../state/lock_store.dart';
import 'pin_pad.dart';

/// Asks for a new PIN twice. Resolves to the PIN, or null if cancelled.
Future<String?> createPinFlow(BuildContext context, {bool changing = false}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => _CreatePinScreen(changing: changing), fullscreenDialog: true),
  );
}

/// Asks for the current PIN (with lockout). Resolves to true when it matched.
Future<bool> verifyPinFlow(BuildContext context) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const _VerifyPinScreen(), fullscreenDialog: true),
  );
  return ok ?? false;
}

class _CreatePinScreen extends StatefulWidget {
  const _CreatePinScreen({required this.changing});

  final bool changing;

  @override
  State<_CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<_CreatePinScreen> {
  String? _first;
  String? _error;
  int _attempt = 0; // remounts the pad between steps

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final confirming = _first != null;
    return Scaffold(
      // Expand: without it the Stack sizes itself to the small close button.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: PinBackground(
              child: PinPad(
                key: ValueKey(_attempt),
                title: confirming
                    ? s.pinConfirmTitle
                    : (widget.changing ? s.pinNewTitle : s.pinCreateTitle),
                subtitle: confirming ? s.pinConfirmBody : s.pinCreateBody,
                error: _error,
                onComplete: (pin) async {
                  if (_first == null) {
                    setState(() {
                      _first = pin;
                      _error = null;
                      _attempt++;
                    });
                    return true;
                  }
                  if (pin == _first) {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, pin);
                    return true;
                  }
                  setState(() {
                    _first = null;
                    _error = s.pinMismatch;
                    _attempt++;
                  });
                  return false;
                },
              ),
            ),
          ),
          const _CloseButton(),
        ],
      ),
    );
  }
}

class _VerifyPinScreen extends StatefulWidget {
  const _VerifyPinScreen();

  @override
  State<_VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends State<_VerifyPinScreen> {
  String? _error;
  int _errors = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final lock = context.watch<LockStore>();
    final until = lock.lockoutRemaining == null ? null : DateTime.now().add(lock.lockoutRemaining!);
    return Scaffold(
      // Expand: without it the Stack sizes itself to the small close button.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: PinBackground(
              child: PinPad(
                title: s.pinCurrentTitle,
                // Distinct text per failure so the pad shakes every time.
                error: _error == null ? null : '$_error${'​' * (_errors % 2)}',
                lockoutUntil: until,
                onComplete: (pin) async {
                  final ok = await lock.verify(pin);
                  if (!mounted) return ok;
                  if (ok) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() {
                      _error = s.pinWrong;
                      _errors++;
                    });
                  }
                  return ok;
                },
              ),
            ),
          ),
          const _CloseButton(),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          tooltip: AppStrings.of(context).cancel,
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),
      ),
    );
  }
}
