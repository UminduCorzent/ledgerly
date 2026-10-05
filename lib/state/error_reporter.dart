import 'package:flutter/material.dart';

import '../core/strings/app_strings.dart';

/// App-wide snackbar access for failures raised outside any widget.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class ErrorReporter {
  const ErrorReporter._();

  static void saveFailed() {
    final m = appMessengerKey.currentState;
    if (m == null) return;
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppStrings.current.saveFailed),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}
