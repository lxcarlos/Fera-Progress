import 'dart:math';
import 'package:flutter/material.dart';

class MascotWidget extends StatefulWidget {
  final int level;
  final Color color;
  final double size;
  final bool jump; // cambia de false a true para disparar un salto de celebración

  const MascotWidget({super.key, required this.level, required this.color, this.size = 140, this.jump = false});

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _blinkController;
  late final AnimationController _jumpController;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _jumpController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scheduleBlink();
  }

  void _scheduleBlink() {
    Future.delayed(Duration(milliseconds: 2500 + Random().nextInt(2500)), () async {
      if (_disposed) return;
      await _blinkController.forward();
      if (_disposed) return;
      await _blinkController.reverse();
      _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(covariant MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jump && !oldWidget.jump) {
      _jumpController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _idleController.dispose();
    _blinkController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idleController, _blinkController, _jumpController]),
        builder: (context, _) {
          final jumpValue = Curves.easeOutBack.transform(
            _jumpController.value < 0.5 ? _jumpController.value * 2 : (1 - _jumpController.value) * 2,
          );
          return CustomPaint(
            painter: _MascotPainter(
              breathing: _idleController.value,
              blink: _blinkController.value,
              jump: jumpValue,
              level: widget.level,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final double breathing;
  final double blink;
  final double jump;
  final int level;
  final Color color;

  _MascotPainter({required this.breathing, required this.blink, required this.jump, required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final breathScale = 1.0 + (breathing * 0.035);
    final jumpOffset = -jump * size.height * 0.10;

    canvas.save();
    canvas.translate(center.dx, center.dy + jumpOffset);
    canvas.scale(1.0, breathScale);
    canvas.translate(-center.dx, -center.dy);

    final bodyRadius = size.width * 0.34;

    // Sombra sutil
    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.15);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + bodyRadius * 1.15), width: bodyRadius * 1.4, height: bodyRadius * 0.35),
      shadowPaint,
    );

    // Cuerpo (blob orgánico)
    final bodyPath = _blobPath(center, bodyRadius);
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(1), color.withOpacity(0.82)],
        center: const Alignment(-0.3, -0.4),
      ).createShader(Rect.fromCircle(center: center, radius: bodyRadius * 1.3));
    canvas.drawPath(bodyPath, bodyPaint);

    // Brillo superior
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.18);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - bodyRadius * 0.28, center.dy - bodyRadius * 0.35), width: bodyRadius * 0.5, height: bodyRadius * 0.3),
      highlightPaint,
    );

    // Ojos
    final eyeY = center.dy - bodyRadius * 0.05;
    final eyeGap = bodyRadius * 0.32;
    final eyeH = bodyRadius * 0.22 * (1 - blink * 0.92);
    final eyePaint = Paint()..color = const Color(0xFF1A1A1A);
    for (final dx in [-eyeGap, eyeGap]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx + dx, eyeY), width: bodyRadius * 0.16, height: eyeH),
        eyePaint,
      );
    }

    // Mejillas (a partir de nivel 3)
    if (level >= 3) {
      final blushPaint = Paint()..color = Colors.pinkAccent.withOpacity(0.35);
      for (final dx in [-eyeGap * 1.7, eyeGap * 1.7]) {
        canvas.drawCircle(Offset(center.dx + dx, eyeY + bodyRadius * 0.22), bodyRadius * 0.12, blushPaint);
      }
    }

    // Sonrisa
    final mouthPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bodyRadius * 0.06
      ..strokeCap = StrokeCap.round;
    final mouthRect = Rect.fromCenter(center: Offset(center.dx, center.dy + bodyRadius * 0.10), width: bodyRadius * 0.5, height: bodyRadius * 0.4);
    canvas.drawArc(mouthRect, 0.25, pi - 0.5, false, mouthPaint);

    // Hojitas (nivel 3+)
    if (level >= 3) {
      _drawLeaf(canvas, Offset(center.dx - bodyRadius * 0.25, center.dy - bodyRadius * 0.92), bodyRadius * 0.32, -0.5, color);
      if (level >= 6) _drawLeaf(canvas, Offset(center.dx + bodyRadius * 0.25, center.dy - bodyRadius * 0.95), bodyRadius * 0.32, 0.5, color);
    }

    // Destellos (nivel 10+)
    if (level >= 10) {
      final sparklePaint = Paint()..color = Colors.amber.withOpacity(0.85);
      _drawSparkle(canvas, Offset(center.dx + bodyRadius * 1.0, center.dy - bodyRadius * 0.6), bodyRadius * 0.14, sparklePaint);
      _drawSparkle(canvas, Offset(center.dx - bodyRadius * 1.05, center.dy - bodyRadius * 0.1), bodyRadius * 0.1, sparklePaint);
    }

    canvas.restore();
  }

  Path _blobPath(Offset center, double r) {
    final path = Path();
    final points = <Offset>[];
    const n = 10;
    final wobble = [0.0, 0.06, -0.03, 0.05, 0.0, -0.05, 0.04, -0.02, 0.05, -0.04];
    for (int i = 0; i < n; i++) {
      final angle = (2 * pi / n) * i;
      final rr = r * (1 + wobble[i]);
      points.add(Offset(center.dx + rr * cos(angle), center.dy + rr * sin(angle)));
    }
    path.moveTo((points[0].dx + points[n - 1].dx) / 2, (points[0].dy + points[n - 1].dy) / 2);
    for (int i = 0; i < n; i++) {
      final next = points[(i + 1) % n];
      final mid = Offset((points[i].dx + next.dx) / 2, (points[i].dy + next.dy) / 2);
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  void _drawLeaf(Canvas canvas, Offset base, double length, double tilt, Color color) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    final leafPaint = Paint()..color = Colors.green.withOpacity(0.85);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.5, -length * 0.5, 0, -length)
      ..quadraticBezierTo(-length * 0.5, -length * 0.5, 0, 0)
      ..close();
    canvas.drawPath(path, leafPaint);
    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, Offset pos, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (pi / 2) * i;
      path.moveTo(pos.dx, pos.dy);
      path.lineTo(pos.dx + r * cos(angle), pos.dy + r * sin(angle));
    }
    canvas.drawPath(path, paint..strokeWidth = r * 0.25..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.breathing != breathing ||
        oldDelegate.blink != blink ||
        oldDelegate.jump != jump ||
        oldDelegate.level != level ||
        oldDelegate.color != color;
  }
}