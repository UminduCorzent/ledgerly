import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Pill-style segmented control used for type, period, theme and breakdown switches.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.selectedColors,
    this.compact = false,
    this.onGradient = false,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Optional per-segment text colour when selected (e.g. type colours).
  final List<Color>? selectedColors;
  final bool compact;

  /// Translucent white styling for use on the hero gradient.
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dur = Motion.of(context, Motion.micro);
    final bg = onGradient ? Colors.white.withValues(alpha: 0.18) : c.surface2;
    final pad = compact ? 3.0 : 4.0;
    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(compact ? 999 : 14),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            for (var i = 0; i < values.length; i++)
              _segment(context, i, dur, c),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, int i, Duration dur, AppColors c) {
    final isSel = values[i] == selected;
    final selBg = onGradient ? Colors.white : c.surface;
    final fg = isSel
        ? (onGradient
            ? const Color(0xFF1E3A8A) // deep blue on the white pill, same in both themes
            : (selectedColors?[i] ?? c.text))
        : (onGradient ? Colors.white : c.muted);
    final child = AnimatedContainer(
      duration: dur,
      curve: Motion.enter,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 10,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: isSel ? selBg : Colors.transparent,
        borderRadius: BorderRadius.circular(compact ? 999 : 10),
      ),
      alignment: Alignment.center,
      child: Text(
        labels[i],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 12.5 : 14,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
    final tappable = Semantics(
      button: true,
      selected: isSel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isSel ? null : () => onChanged(values[i]),
        child: child,
      ),
    );
    return compact ? tappable : Expanded(child: tappable);
  }
}
