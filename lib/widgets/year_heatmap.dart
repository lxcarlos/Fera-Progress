import 'package:flutter/material.dart';

/// Heatmap estilo GitHub: una cuadrícula de semanas x días, donde cada
/// cuadrito se pinta más o menos intenso según cuántos hábitos se
/// completaron ese día. Se desplaza horizontal y arranca mostrando los
/// meses más recientes.
class YearHeatmap extends StatelessWidget {
  final int year;
  final Map<String, int> countsByDate; // "yyyy-MM-dd" -> cantidad completada

  const YearHeatmap({super.key, required this.year, required this.countsByDate});

  static const List<String> _monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  String _key(DateTime d) => d.toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final jan1 = DateTime(year, 1, 1);
    // La grilla arranca en el domingo antes (o el mismo) del 1 de enero,
    // como hace GitHub, para que las semanas queden alineadas de domingo a sábado.
    final gridStart = jan1.subtract(Duration(days: jan1.weekday % 7));
    final dec31 = DateTime(year, 12, 31);
    final totalDays = dec31.difference(gridStart).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    final maxCount = countsByDate.values.isEmpty ? 0 : countsByDate.values.reduce((a, b) => a > b ? a : b);

    Color colorFor(int count) {
      if (count == 0) return theme.colorScheme.onSurface.withOpacity(0.07);
      if (maxCount == 0) return accent.withOpacity(0.3);
      final ratio = count / maxCount;
      final level = ratio <= 0.25
          ? 0.3
          : ratio <= 0.5
              ? 0.5
              : ratio <= 0.75
                  ? 0.7
                  : 0.95;
      return accent.withOpacity(level);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // al abrir, muestra directo los meses más recientes
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Etiquetas de mes arriba del bloque de semanas que le corresponde.
            Row(
              children: List.generate(totalWeeks, (week) {
                final weekStart = gridStart.add(Duration(days: week * 7));
                final showLabel = weekStart.day <= 7 && weekStart.year == year;
                return SizedBox(
                  width: 13,
                  child: showLabel
                      ? Text(
                          _monthNames[weekStart.month - 1],
                          style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        )
                      : null,
                );
              }),
            ),
            const SizedBox(height: 3),
            Row(
              children: List.generate(totalWeeks, (week) {
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Column(
                    children: List.generate(7, (dow) {
                      final day = gridStart.add(Duration(days: week * 7 + dow));
                      if (day.year != year) {
                        return const SizedBox(width: 11, height: 11);
                      }
                      final count = countsByDate[_key(day)] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Tooltip(
                          message: '${day.day}/${day.month}/${day.year}: $count completado${count == 1 ? '' : 's'}',
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(color: colorFor(count), borderRadius: BorderRadius.circular(2.5)),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}