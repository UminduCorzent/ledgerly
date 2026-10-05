import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/motion.dart';
import '../../domain/pin_hasher.dart';

/// PIN entry used by the lock screen and the set/verify flows: four dots,
/// a status line, round keys, and an optional extra key (biometrics) bottom-left.
///
/// Drawn on the brand gradient, so text and keys are white in both themes.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onComplete,
    this.subtitle,
    this.error,
    this.lockoutUntil,
    this.extraKey,
    this.busy = false,
  });

  final String title;
  final String? subtitle;

  /// Red status line (e.g. "Wrong PIN"); setting a new value shakes the dots.
  final String? error;

  /// While set and in the future, keys are disabled and a countdown shows.
  final DateTime? lockoutUntil;

  /// Called with the 4 digits. Return true to keep them (success), false to clear.
  final Future<bool> Function(String pin) onComplete;
  final Widget? extraKey;
  final bool busy;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _checking = false;
  Timer? _ticker;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (widget.error != null && widget.error != old.error) _shake.forward(from: 0);
    _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (_lockedOut) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_lockedOut) _ticker?.cancel();
      });
    }
  }

  bool get _lockedOut {
    final u = widget.lockoutUntil;
    return u != null && u.isAfter(DateTime.now());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String d) async {
    if (_checking || _lockedOut || widget.busy || _pin.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == kPinLength) {
      setState(() => _checking = true);
      final keep = await widget.onComplete(_pin);
      if (!mounted) return;
      setState(() {
        _checking = false;
        if (!keep) _pin = '';
      });
      if (!keep) HapticFeedback.mediumImpact();
    }
  }

  void _back() {
    if (_pin.isEmpty || _checking) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    const white = Colors.white;
    final lockedOut = _lockedOut;
    final secondsLeft = lockedOut
        ? (widget.lockoutUntil!.difference(DateTime.now()).inMilliseconds / 1000).ceil()
        : 0;
    final status = lockedOut ? s.pinLockedOut(secondsLeft) : (widget.error ?? widget.subtitle ?? '');
    final statusColor = (lockedOut || widget.error != null) ? const Color(0xFFFFE4E6) : white.withValues(alpha: 0.85);

    Widget key(String label, {VoidCallback? onTap, Widget? child, String? semantics}) => Semantics(
          button: true,
          label: semantics ?? label,
          excludeSemantics: true,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Material(
              color: white.withValues(alpha: child == null && label.isEmpty ? 0 : 0.16),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(
                  child: child ??
                      Text(label, style: const TextStyle(color: white, fontSize: 26, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        );

    final enabled = !lockedOut && !_checking && !widget.busy;
    Widget digit(String d) => key(d, onTap: enabled ? () => _press(d) : null);

    return Opacity(
      opacity: lockedOut ? 0.6 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Semantics(
            label: s.pinProgress(_pin.length),
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                return Transform.translate(
                  offset: Offset(math.sin(t * math.pi * 6) * 10 * (1 - t), 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < kPinLength; i++)
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.micro),
                      margin: const EdgeInsets.symmetric(horizontal: 9),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? white : Colors.transparent,
                        border: Border.all(color: white, width: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: Text(
              status,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 22),
                    digit(row[i]),
                  ],
                ],
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 72, height: 72, child: widget.extraKey),
              const SizedBox(width: 22),
              digit('0'),
              const SizedBox(width: 22),
              key(
                '',
                semantics: s.backspace,
                onTap: _back,
                child: const Icon(Icons.backspace_outlined, color: white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-bleed brand gradient used behind every PIN screen.
class PinBackground extends StatelessWidget {
  const PinBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF1D4ED8), Color(0xFF0E7490)]
              : const [Color(0xFF2563EB), Color(0xFF06B6D4)],
        ),
      ),
      child: SafeArea(child: Center(child: SingleChildScrollView(child: child))),
    );
  }
}
