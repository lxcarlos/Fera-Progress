import 'package:flutter/material.dart';

/// Pequeño anillo de progreso que muestra el % de hábitos cumplidos hoy.
/// Se usa en la pantalla de Hábitos, junto al título.
class DayPercentRing extends StatelessWidget {
  final double percent; // 0..1
  final bool hasData;
  final VoidCallback? onTap;
  final double size;

  const DayPercentRing({
    super.key,
    required this.percent,
    this.hasData = true,
    this.onTap,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final clamped = percent.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onSurface.withOpacity(0.08)),
              ),
            ),
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: hasData ? clamped : 0,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              hasData ? '${(clamped * 100).round()}' : '–',
              style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}