import 'package:flutter/material.dart';

class ElderEaseLogo extends StatelessWidget {
  const ElderEaseLogo({
    super.key,
    this.size = 120,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ElderEaseLogoPainter(),
      ),
    );
  }
}

class _ElderEaseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..isAntiAlias = true;

    final outerRect = Rect.fromCircle(
      center: center,
      radius: size.shortestSide * 0.48,
    );

    final outerShadow = Paint()
      ..color = const Color(0x1F000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center.translate(0, 6), size.shortestSide * 0.44, outerShadow);

    final outerGradient = RadialGradient(
      colors: [
        const Color(0xFFFFC56A),
        const Color(0xFFE8922A),
        const Color(0xFFCC6F11),
      ],
      stops: const [0.0, 0.72, 1.0],
    ).createShader(outerRect);

    paint.shader = outerGradient;
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(size.width * 0.22)),
      paint,
    );

    paint.shader = null;
    paint.color = const Color(0x26FFFFFF);
    canvas.drawCircle(
      center.translate(-size.width * 0.14, -size.height * 0.16),
      size.shortestSide * 0.16,
      paint,
    );

    paint.color = const Color(0xFFFFFFFF);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.24,
      paint,
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE7A24A);
    canvas.drawCircle(center, size.shortestSide * 0.23, ringPaint);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.05
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8FB9A9);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.shortestSide * 0.31),
      -2.35,
      0.78,
      false,
      accentPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.shortestSide * 0.31),
      0.45,
      0.82,
      false,
      accentPaint,
    );

    final headPaint = Paint()..color = const Color(0xFFE8922A);
    canvas.drawCircle(
      Offset(center.dx, center.dy - size.height * 0.10),
      size.shortestSide * 0.055,
      headPaint,
    );

    final bodyPath = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.03)
      ..cubicTo(
        center.dx + size.width * 0.02,
        center.dy + size.height * 0.03,
        center.dx + size.width * 0.10,
        center.dy + size.height * 0.10,
        center.dx + size.width * 0.14,
        center.dy + size.height * 0.16,
      )
      ..moveTo(center.dx, center.dy - size.height * 0.01)
      ..cubicTo(
        center.dx - size.width * 0.03,
        center.dy + size.height * 0.04,
        center.dx - size.width * 0.08,
        center.dy + size.height * 0.10,
        center.dx - size.width * 0.12,
        center.dy + size.height * 0.16,
      );

    final bodyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE8922A);
    canvas.drawPath(bodyPath, bodyPaint);

    final canePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.03
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5B6C66);
    final canePath = Path()
      ..moveTo(center.dx + size.width * 0.17, center.dy + size.height * 0.00)
      ..quadraticBezierTo(
        center.dx + size.width * 0.22,
        center.dy + size.height * 0.11,
        center.dx + size.width * 0.18,
        center.dy + size.height * 0.25,
      )
      ..moveTo(center.dx + size.width * 0.17, center.dy + size.height * 0.10)
      ..lineTo(center.dx + size.width * 0.24, center.dy + size.height * 0.10);
    canvas.drawPath(canePath, canePaint);
  }

  @override
  bool shouldRepaint(covariant _ElderEaseLogoPainter oldDelegate) => false;
}