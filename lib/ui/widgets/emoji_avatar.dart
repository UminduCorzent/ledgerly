import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Emoji on a soft circle tinted with the item's own colour (categories, accounts).
class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar({
    super.key,
    required this.emoji,
    required this.color,
    this.size = 40,
  });

  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.tinted(color),
        shape: BoxShape.circle,
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.48, height: 1.1),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

/// The violet ⇄ circle used for transfer rows.
class TransferAvatar extends StatelessWidget {
  const TransferAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.tinted(c.transfer), shape: BoxShape.circle),
      child: Icon(Icons.swap_horiz_rounded, color: c.transfer, size: size * 0.55),
    );
  }
}
