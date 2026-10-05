import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';

/// The app's text-field look: filled, borderless, brand outline on focus.
InputDecoration appInputDecoration(
  BuildContext context, {
  String? hint,
  Widget? prefixIcon,
  String? errorText,
}) {
  final c = context.colors;
  OutlineInputBorder border(BorderSide side) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: side);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.muted),
    prefixIcon: prefixIcon,
    errorText: errorText,
    filled: true,
    fillColor: c.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(BorderSide.none),
    enabledBorder: border(BorderSide.none),
    focusedBorder: border(BorderSide(color: c.primary, width: 1.5)),
    errorBorder: border(BorderSide(color: c.expense, width: 1.5)),
    focusedErrorBorder: border(BorderSide(color: c.expense, width: 1.5)),
  );
}

/// Flat app bar matching the page background.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.leading, this.actions});

  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppBar(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      actions: actions,
      title: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text),
      ),
    );
  }
}

/// Standard content card: one per role, not on every block.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.line),
        boxShadow: c.cardShadow
            ? const [
                BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 42)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, height: 1.45),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Small grey "Excluded" pill.
class ExcludedPill extends StatelessWidget {
  const ExcludedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(999)),
      child: Text(
        AppStrings.of(context).excludedPill,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted),
      ),
    );
  }
}

/// Floating snackbar, optionally with Undo. Replaces any visible snackbar.
void showSnack(BuildContext context, String message, {VoidCallback? onUndo}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      action: onUndo == null
          ? null
          : SnackBarAction(label: AppStrings.of(context).undo, onPressed: onUndo),
    ),
  );
}

/// Confirmation for destructive actions. Resolves to true only on the red button.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  String? action,
}) async {
  final s = AppStrings.of(context);
  final c = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.expense,
            foregroundColor: Colors.white,
            minimumSize: const Size(88, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action ?? s.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
