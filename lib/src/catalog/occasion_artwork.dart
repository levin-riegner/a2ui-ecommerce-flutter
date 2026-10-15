import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original geometric occasion artwork, drawn locally without external media.
/// The staggered collage retains the reference layout using redistributable art.
class OccasionArtwork extends StatelessWidget {
  const OccasionArtwork({
    super.key,
    required this.seed,
    this.width,
    this.height,
  });

  final int seed;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _OccasionPainter(seed)),
    ),
  );
}

class _OccasionPainter extends CustomPainter {
  const _OccasionPainter(this.seed);
  final int seed;

  static const _palettes = [
    [Color(0xffe8d9c5), Color(0xff89765a), Color(0xff38483d)],
    [Color(0xffd6d5c8), Color(0xff8d9c91), Color(0xff37483e)],
    [Color(0xffe2c7ae), Color(0xffab7966), Color(0xff5b3d37)],
    [Color(0xffe7dfd0), Color(0xff9b9e8b), Color(0xff424d43)],
    [Color(0xffd6dce0), Color(0xff8d9caa), Color(0xff3d4d5a)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _palettes[(seed - 1).abs() % _palettes.length];
    canvas.save();
    canvas.scale(size.width / 160, size.height / 210);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 160, 210),
      Paint()..color = palette[0],
    );
    final fill = Paint()..color = palette[1];
    final ink = Paint()
      ..color = palette[2]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    canvas.drawCircle(Offset(seed.isEven ? 120 : 36, 38), 18, fill);
    canvas.drawPath(
      Path()
        ..moveTo(0, 157)
        ..quadraticBezierTo(80, 125 + seed % 4 * 8, 160, 162)
        ..lineTo(160, 210)
        ..lineTo(0, 210)
        ..close(),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(37, 59, 86, 115),
        const Radius.circular(43),
      ),
      Paint()..color = palette[0].withValues(alpha: .7),
    );
    // A simple garment silhouette varies with the card; no source image is used.
    final garment = seed % 3 == 0
        ? (Path()
            ..moveTo(63, 83)
            ..lineTo(97, 83)
            ..lineTo(101, 157)
            ..lineTo(84, 157)
            ..lineTo(80, 111)
            ..lineTo(76, 157)
            ..lineTo(59, 157)
            ..close())
        : (Path()
            ..moveTo(65, 78)
            ..quadraticBezierTo(80, 88, 95, 78)
            ..lineTo(112, 96)
            ..lineTo(101, 110)
            ..lineTo(95, 104)
            ..lineTo(seed.isEven ? 104 : 119, 157)
            ..lineTo(seed.isEven ? 56 : 41, 157)
            ..lineTo(65, 104)
            ..lineTo(59, 110)
            ..lineTo(48, 96)
            ..close());
    canvas.drawPath(garment, Paint()..color = palette[2]);
    canvas.drawLine(
      const Offset(80, 91),
      const Offset(80, 146),
      Paint()
        ..color = palette[0].withValues(alpha: .6)
        ..strokeWidth = 1,
    );
    canvas.drawArc(
      const Rect.fromLTWH(68, 57, 24, 20),
      math.pi,
      math.pi,
      false,
      ink,
    );
    canvas.drawLine(const Offset(80, 67), const Offset(80, 74), ink);
    canvas.drawLine(const Offset(51, 183), const Offset(109, 183), ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OccasionPainter oldDelegate) => oldDelegate.seed != seed;
}
