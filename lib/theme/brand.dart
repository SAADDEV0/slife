import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The SLife mark: a sunrise-gradient tile with a hand-drawn "S" and a small
/// sun. Shared by the in-app logo and the launcher icon generator.
class Brand {
  Brand._();

  static const violet = Color(0xFF6D5DF6);
  static const orchid = Color(0xFFB45EDB);
  static const coral = Color(0xFFFF7A59);
  static const sun = Color(0xFFFFE3B3);

  /// The "S" in a 108×108 adaptive-icon viewport (72×72 visible).
  static Path sPath() => Path()
    ..moveTo(66.5, 41.5)
    ..cubicTo(63.5, 36.5, 58.5, 34.5, 53.5, 34.5)
    ..cubicTo(46.5, 34.5, 41.5, 38.5, 41.5, 44.5)
    ..cubicTo(41.5, 51, 47, 53, 54, 54.5)
    ..cubicTo(61, 56, 66.5, 58.5, 66.5, 65)
    ..cubicTo(66.5, 71, 61.5, 74.5, 54.5, 74.5)
    ..cubicTo(49, 74.5, 44, 72, 41.5, 67.5);

  static void paintIcon(Canvas canvas, double size, {required bool rounded}) {
    final rect = Offset.zero & Size(size, size);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.235));
    final background = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size, size),
        const [violet, orchid, coral],
        const [0, 0.5, 1],
      );
    if (rounded) {
      canvas.drawRRect(rrect, background);
    } else {
      canvas.drawRect(rect, background);
    }

    canvas.save();
    if (rounded) canvas.clipRRect(rrect);
    canvas.drawCircle(
      Offset(size * 0.86, size * 0.1),
      size * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    canvas.restore();

    // Map the visible 72×72 window of the 108 viewport onto the tile.
    canvas.save();
    canvas.scale(size / 72);
    canvas.translate(-18, -18);
    canvas.drawPath(
      sPath(),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(71.5, 33.5), 4.2, Paint()..color = sun);
    canvas.restore();
  }
}

class SLifeMarkPainter extends CustomPainter {
  const SLifeMarkPainter();

  @override
  void paint(Canvas canvas, Size size) =>
      Brand.paintIcon(canvas, size.shortestSide, rounded: true);

  @override
  bool shouldRepaint(SLifeMarkPainter oldDelegate) => false;
}
