import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'PlusJakartaSans';

  // Built once; rebuilding ThemeData on every frame of a theme change is waste.
  static final ThemeData light = _build(AppColors.light, Brightness.light);
  static final ThemeData dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: c.primary, brightness: b)
        .copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      outline: c.line,
      outlineVariant: c.line,
      error: c.expense,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: c.bg,
      // Ripple instead of the shader-based sparkle: cheaper on mid-range phones.
      splashFactory: InkRipple.splashFactory,
      extensions: [c],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
      // App bar and text-field styling is applied per widget (AppTopBar, appInputDecoration)
      // because those ThemeData component types were renamed in recent Flutter versions.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primary.withValues(alpha: 0.18),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? c.text : c.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? c.text : c.muted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 3,
        extendedTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: c.bg,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          foregroundColor: c.text,
          side: BorderSide(color: c.line, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
