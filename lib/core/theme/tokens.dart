import 'package:flutter/material.dart';

/// Design tokens from the UI spec (§2). Colour carries meaning:
/// income / expense / transfer, category tints, brand blue for actions.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.heroA,
    required this.heroB,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warn,
    required this.warnBg,
    required this.tint,
    required this.cardShadow,
  });

  final Color primary;
  final Color onPrimary;
  final Color heroA;
  final Color heroB;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color muted;
  final Color income;
  final Color expense;
  final Color transfer;
  final Color warn;
  final Color warnBg;

  /// Alpha used to tint a category/account colour behind its emoji.
  final double tint;

  /// Light theme gets one soft shadow per card; dark theme none.
  final bool cardShadow;

  static const light = AppColors(
    primary: Color(0xFF2563EB),
    onPrimary: Color(0xFFFFFFFF),
    heroA: Color(0xFF2563EB),
    heroB: Color(0xFF06B6D4),
    bg: Color(0xFFF5F8FD),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF3FB),
    line: Color(0xFFE3E9F3),
    text: Color(0xFF0F172A),
    muted: Color(0xFF5B6B82),
    income: Color(0xFF0E9F6E),
    expense: Color(0xFFE11D48),
    transfer: Color(0xFF7C3AED),
    warn: Color(0xFFB45309),
    warnBg: Color(0xFFFEF3C7),
    tint: 0.14,
    cardShadow: true,
  );

  static const dark = AppColors(
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF0B1220),
    heroA: Color(0xFF1D4ED8),
    heroB: Color(0xFF0891B2),
    bg: Color(0xFF0B1220),
    surface: Color(0xFF121B2D),
    surface2: Color(0xFF1A2538),
    line: Color(0xFF24324B),
    text: Color(0xFFE2E8F0),
    muted: Color(0xFF94A3B8),
    income: Color(0xFF34D399),
    expense: Color(0xFFFB7185),
    transfer: Color(0xFFA78BFA),
    warn: Color(0xFFFBBF24),
    warnBg: Color(0xFF3A2E10),
    tint: 0.22,
    cardShadow: false,
  );

  Color tinted(Color c) => c.withValues(alpha: tint);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      heroA: l(heroA, other.heroA),
      heroB: l(heroB, other.heroB),
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      income: l(income, other.income),
      expense: l(expense, other.expense),
      transfer: l(transfer, other.transfer),
      warn: l(warn, other.warn),
      warnBg: l(warnBg, other.warnBg),
      tint: tint + (other.tint - tint) * t,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Corner radii (UI spec §2).
class Radii {
  const Radii._();
  static const double card = 24;
  static const double tile = 16;
  static const double sheet = 28;
  static const double button = 16;
}
