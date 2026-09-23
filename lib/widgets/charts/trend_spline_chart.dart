import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/stats_data.dart';
import '../../services/haptic_service.dart';

class TrendSplineChart extends StatefulWidget {
  final List<DailyDataPoint> series;
  final Color accentColor;
  final bool isDark;
  final String currentPeriodLabel;
  final String previousPeriodLabel;

  const TrendSplineChart({
    super.key,
    required this.series,
    required this.accentColor,
    required this.isDark,
    this.currentPeriodLabel = 'Período actual',
    this.previousPeriodLabel = 'Período anterior',
  });

  @override
  State<TrendSplineChart> createState() => _TrendSplineChartState();
}

class _TrendSplineChartState extends State<TrendSplineChart> with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animController;
  late Animation<double> _curvedAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _curvedAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant TrendSplineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) {
      _selectedIndex = null;
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPosition, double chartWidth, double leftPadding, double rightPadding) {
    if (widget.series.isEmpty) return;
    final usableWidth = chartWidth - leftPadding - rightPadding;
    if (usableWidth <= 0) return;

    final touchX = (localPosition.dx - leftPadding).clamp(0.0, usableWidth);
    final count = widget.series.length;
    final step = count > 1 ? usableWidth / (count - 1) : 0.0;

    int newIndex;
    if (step > 0) {
      newIndex = (touchX / step).round().clamp(0, count - 1);
    } else {
      newIndex = 0;
    }

    if (newIndex != _selectedIndex) {
      AppHaptics.selectionClick();
      setState(() {
        _selectedIndex = newIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    if (widget.series.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Sin suficientes datos para graficar',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final selectedPoint = _selectedIndex != null && _selectedIndex! < widget.series.length
        ? widget.series[_selectedIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leyenda superior y detalle interactivo (responsive para evitar desbordes)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              // Leyendas de Períodos
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Leyenda Período Actual
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: widget.accentColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.currentPeriodLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Leyenda Período Anterior
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 2,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white38 : Colors.black38,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.previousPeriodLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Indicador de arrastre
              if (_selectedIndex == null)
                Text(
                  'Desliza para explorar',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Tooltip flotante interactivo cuando se arrastra
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: selectedPoint != null
              ? Container(
                  key: ValueKey(selectedPoint.date),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2024) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: widget.accentColor),
                      const SizedBox(width: 6),
                      Text(
                        selectedPoint.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Actual: ',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${selectedPoint.count}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: widget.accentColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Prev: ',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${selectedPoint.previousCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delta
                      _buildDeltaBadge(selectedPoint.count - selectedPoint.previousCount),
                    ],
                  ),
                )
              : const SizedBox(height: 32),
        ),

        // Área del gráfico con CustomPainter y Gesture Scrubbing
        LayoutBuilder(
          builder: (context, constraints) {
            const chartHeight = 190.0;
            const leftPad = 28.0;
            const rightPad = 12.0;

            return GestureDetector(
              onPanDown: (d) => _handleTouch(d.localPosition, constraints.maxWidth, leftPad, rightPad),
              onPanUpdate: (d) => _handleTouch(d.localPosition, constraints.maxWidth, leftPad, rightPad),
              onPanEnd: (_) => setState(() => _selectedIndex = null),
              onPanCancel: () => setState(() => _selectedIndex = null),
              onTapDown: (d) => _handleTouch(d.localPosition, constraints.maxWidth, leftPad, rightPad),
              onTapUp: (_) => setState(() => _selectedIndex = null),
              child: AnimatedBuilder(
                animation: _curvedAnim,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, chartHeight),
                    painter: _SplineChartPainter(
                      series: widget.series,
                      accentColor: widget.accentColor,
                      isDark: isDark,
                      selectedIndex: _selectedIndex,
                      animProgress: _curvedAnim.value,
                      leftPad: leftPad,
                      rightPad: rightPad,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeltaBadge(int delta) {
    if (delta == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('=', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    }
    final isPos = delta > 0;
    final color = isPos ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${isPos ? '+' : ''}$delta',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _SplineChartPainter extends CustomPainter {
  final List<DailyDataPoint> series;
  final Color accentColor;
  final bool isDark;
  final int? selectedIndex;
  final double animProgress;
  final double leftPad;
  final double rightPad;

  _SplineChartPainter({
    required this.series,
    required this.accentColor,
    required this.isDark,
    required this.selectedIndex,
    required this.animProgress,
    required this.leftPad,
    required this.rightPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final topPad = 14.0;
    final bottomPad = 24.0;
    final usableW = size.width - leftPad - rightPad;
    final usableH = size.height - topPad - bottomPad;

    // Calcular máximo
    int maxVal = 0;
    for (final p in series) {
      if (p.count > maxVal) maxVal = p.count;
      if (p.previousCount > maxVal) maxVal = p.previousCount;
    }
    if (maxVal < 4) maxVal = 4; // Escala mínima limpia

    // 1. Dibujar líneas de cuadrícula horizontales
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.40),
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
    );

    const gridLines = 3;
    for (int i = 0; i <= gridLines; i++) {
      final frac = i / gridLines;
      final y = topPad + usableH * (1.0 - frac);
      final valueLabel = (maxVal * frac).round().toString();

      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);

      final textSpan = TextSpan(text: valueLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(leftPad - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    final count = series.length;
    final stepX = count > 1 ? usableW / (count - 1) : 0.0;

    // Puntos para curva actual y previa
    final List<Offset> curPoints = [];
    final List<Offset> prevPoints = [];

    for (int i = 0; i < count; i++) {
      final x = leftPad + (i * stepX);
      final p = series[i];

      // Aplicar progreso de animación a Y
      final curY = topPad + usableH * (1.0 - (p.count / maxVal) * animProgress);
      final prevY = topPad + usableH * (1.0 - (p.previousCount / maxVal) * animProgress);

      curPoints.add(Offset(x, curY));
      prevPoints.add(Offset(x, prevY));
    }

    // 2. Dibujar curva previa (referencia atenuada / discontinua)
    if (prevPoints.isNotEmpty) {
      final prevPath = _createSplinePath(prevPoints);
      final prevPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(prevPath, prevPaint);
    }

    // 3. Dibujar área sombreada con gradiente bajo curva actual
    if (curPoints.isNotEmpty) {
      final curPath = _createSplinePath(curPoints);

      final fillPath = Path.from(curPath)
        ..lineTo(curPoints.last.dx, topPad + usableH)
        ..lineTo(curPoints.first.dx, topPad + usableH)
        ..close();

      final fillPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, topPad),
          Offset(0, topPad + usableH),
          [
            accentColor.withValues(alpha: isDark ? 0.32 : 0.22),
            accentColor.withValues(alpha: 0.0),
          ],
        )
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);

      // 4. Dibujar curva principal (actual)
      final mainLinePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Sombra sutil bajo la línea
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: isDark ? 0.45 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawPath(curPath, glowPaint);
      canvas.drawPath(curPath, mainLinePaint);
    }

    // 5. Dibujar etiquetas de eje X (fechas/días clave para no amontonar)
    final labelStride = count > 14 ? (count / 6).ceil() : (count > 7 ? 2 : 1);
    for (int i = 0; i < count; i += labelStride) {
      final x = leftPad + (i * stepX);
      final label = series[i].label;

      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 5));
    }

    // Asegurar última etiqueta si no coincidió
    if ((count - 1) % labelStride != 0) {
      final lastIndex = count - 1;
      final x = leftPad + (lastIndex * stepX);
      final tp = TextPainter(
        text: TextSpan(text: series[lastIndex].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 5));
    }

    // 6. Si hay interacción activa (selectedIndex): dibujar cursor y puntos
    if (selectedIndex != null && selectedIndex! < curPoints.length) {
      final selCur = curPoints[selectedIndex!];
      final selPrev = prevPoints[selectedIndex!];

      // Línea guía vertical
      final guidePaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(selCur.dx, topPad),
        Offset(selCur.dx, topPad + usableH),
        guidePaint,
      );

      // Punto período previo
      final prevDotBg = Paint()
        ..color = isDark ? const Color(0xFF141416) : Colors.white
        ..style = PaintingStyle.fill;
      final prevDotBorder = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(selPrev, 4.0, prevDotBg);
      canvas.drawCircle(selPrev, 4.0, prevDotBorder);

      // Punto período actual (resaltado)
      final glowDot = Paint()
        ..color = accentColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      final curDotBorder = Paint()
        ..color = isDark ? Colors.black : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final curDotFill = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(selCur, 7.0, glowDot);
      canvas.drawCircle(selCur, 5.5, curDotFill);
      canvas.drawCircle(selCur, 5.5, curDotBorder);
    }
  }

  /// Construye una ruta suave usando curvas cúbicas de Bézier (Catmull-Rom spline)
  Path _createSplinePath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points.first.dx, points.first.dy);
      return path;
    }

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      // Tension factor 0.20 para máxima suavidad sin picos extraños
      const tension = 0.20;
      final cp1x = p1.dx + (p2.dx - p0.dx) * tension;
      final cp1y = p1.dy + (p2.dy - p0.dy) * tension;

      final cp2x = p2.dx - (p3.dx - p1.dx) * tension;
      final cp2y = p2.dy - (p3.dy - p1.dy) * tension;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.isDark != isDark;
  }
}
