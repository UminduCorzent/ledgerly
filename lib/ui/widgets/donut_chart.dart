import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';

class DonutSlice {
  const DonutSlice(this.id, this.value, this.color);

  final String id;
  final double value;
  final Color color;
}

/// A lightweight donut. Draws in once per data change; tapping a slice reports its id.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.trackColor,
    this.highlighted,
    this.onTapSlice,
    this.size = 170,
    this.thickness = 22,
    this.center,
  });

  final List<DonutSlice> slices;
  final Color trackColor;
  final String? highlighted;
  final ValueChanged<String?>? onTapSlice;
  final double size;
  final double thickness;
  final Widget? center;

  String get _signature => slices.map((s) => '${s.id}:${s.value.toStringAsFixed(2)}').join('|');

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.emphasis);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: GestureDetector(
          onTapUp: onTapSlice == null ? null : (d) => onTapSlice!(_hitTest(d.localPosition)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Keyed on the data, so the draw-in plays when the numbers change, not on every rebuild.
              TweenAnimationBuilder<double>(
                key: ValueKey(_signature),
                tween: Tween(begin: duration == Duration.zero ? 1 : 0, end: 1),
                duration: duration,
                curve: Motion.enter,
                builder: (context, t, _) => CustomPaint(
                  size: Size.square(size),
                  painter: _DonutPainter(
                    slices: slices,
                    progress: t,
                    thickness: thickness,
                    track: trackColor,
                    highlighted: highlighted,
                  ),
                ),
              ),
              if (center != null)
                SizedBox(width: size - thickness * 2 - 16, child: center),
            ],
          ),
        ),
      ),
    );
  }

  String? _hitTest(Offset p) {
    final r = size / 2;
    final dx = p.dx - r, dy = p.dy - r;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < r - thickness - 6 || dist > r + 4) return null;
    // Angle from 12 o'clock, clockwise, in [0, 2π).
    var a = math.atan2(dy, dx) + math.pi / 2;
    if (a < 0) a += math.pi * 2;
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return null;
    var acc = 0.0;
    for (final s in slices) {
      acc += s.value / total * math.pi * 2;
      if (a <= acc) return s.id;
    }
    return null;
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.progress,
    required this.thickness,
    required this.track,
    required this.highlighted,
  });

  final List<DonutSlice> slices;
  final double progress;
  final double thickness;
  final Color track;
  final String? highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - thickness / 2,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    const gap = 0.025; // radians between slices
    final sweepTotal = math.pi * 2 * progress;
    var start = -math.pi / 2;
    for (final s in slices) {
      final full = s.value / total * math.pi * 2;
      final sweep = math.min(full, math.max(0.0, sweepTotal - (start + math.pi / 2)));
      if (sweep <= 0) break;
      final dim = highlighted != null && highlighted != s.id;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted == s.id ? thickness + 4 : thickness
        ..color = dim ? s.color.withValues(alpha: 0.28) : s.color;
      final visible = slices.length > 1 ? math.max(0.0, sweep - gap) : sweep;
      canvas.drawArc(rect, start, visible, false, p);
      start += full;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.highlighted != highlighted ||
      old.slices != slices ||
      old.track != track;
}
