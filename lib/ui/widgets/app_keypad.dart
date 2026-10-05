import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/amount_input.dart';

/// In-app number pad with a large Save button beside it.
class AppKeypad extends StatelessWidget {
  const AppKeypad({
    super.key,
    required this.onKey,
    required this.onClear,
    required this.onSave,
    required this.saveLabel,
    required this.saveColor,
    this.allowDecimal = true,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final String saveLabel;
  final Color saveColor;
  final bool allowDecimal;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    [kKeyDecimal, '0', kKeyBackspace],
  ];

  static const double keyHeight = 54;
  static const double gap = 8;
  static const double height = keyHeight * 4 + gap * 3;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // Pick readable text for whichever type colour the button has in this theme.
    final saveFg = ThemeData.estimateBrightnessForColor(saveColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0B1220);
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  for (var r = 0; r < _rows.length; r++) ...[
                    if (r > 0) const SizedBox(height: gap),
                    SizedBox(
                      height: keyHeight,
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            Expanded(child: _buildKey(_rows[r][i], s)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: Material(
                color: saveColor,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onSave,
                  child: Center(
                    child: Text(
                      saveLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: saveFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String k, AppStrings s) => _Key(
        label: k == kKeyBackspace ? null : k,
        icon: k == kKeyBackspace ? Icons.backspace_outlined : null,
        semantics: k == kKeyBackspace ? s.backspace : (k == kKeyDecimal ? s.decimalPoint : k),
        enabled: k != kKeyDecimal || allowDecimal,
        onTap: () {
          HapticFeedback.selectionClick();
          onKey(k);
        },
        onLongPress: k == kKeyBackspace ? onClear : null,
      );
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.icon,
    required this.semantics,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
  });

  final String? label;
  final IconData? icon;
  final String semantics;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: c.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          onLongPress: onLongPress,
          child: Center(
            child: icon != null
                ? Icon(icon, color: c.text, size: 22)
                : Text(
                    label!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: enabled ? c.text : c.muted.withValues(alpha: 0.4),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
