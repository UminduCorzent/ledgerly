import 'package:flutter/widgets.dart';

/// Motion tokens (UI spec §6): fast, purposeful, never looping.
class Motion {
  const Motion._();

  static const Duration micro = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasis = Duration(milliseconds: 450);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// True when the OS asks for reduced motion — every animation becomes instant.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
