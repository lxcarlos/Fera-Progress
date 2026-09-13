import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/stats_data.dart';

class ConsistencyChart extends StatefulWidget {
  final List<DailyDataPoint> series;
  final Color accentColor;
  final bool isDark;
  final StatsTimeRange timeRange;

  const ConsistencyChart({
    super.key,
    required this.series,
    required this.accentColor,
    required this.isDark,
    required this.timeRange,
  });

  @override
  State<ConsistencyChart> createState() => _ConsistencyChartState();
}

class _ConsistencyChartState extends State<ConsistencyChart> {
  DailyDataPoint? _selectedPoint;

  @override
  void didUpdateWidget(covariant ConsistencyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeRange != widget.timeRange || oldWidget.series != widget.series) {
      _selectedPoint = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    if (widget.series.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Sin registros de consistencia',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final isHeatmapMode = widget.timeRange == StatsTimeRange.threeMonths ||
        widget.timeRange == StatsTimeRange.sixMonths ||
        widget.timeRange == StatsTimeRange.oneYear;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detalle flotante interactivo del día seleccionado
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          alignment: Alignment.centerLeft,
          child: _selectedPoint != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2024) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_rounded, size: 13, color: widget.accentColor),
                      const SizedBox(width: 6),
                      Text(
                        _formatPointDate(_selectedPoint!.date),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_selectedPoint!.count} completados',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: widget.accentColor,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  'Toca cualquier día para inspeccionar su volumen',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
        ),

        const SizedBox(height: 8),

        // Visualización: Barras (7D y 30D) o Bloques de Calor (90D, 180D, 365D)
        if (!isHeatmapMode)
          _buildBarChart(context, isDark)
        else
          _buildHeatmapGrid(context, isDark),

        const SizedBox(height: 12),

        // Leyenda de intensidad
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Menos',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 6),
            ...List.generate(5, (level) {
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _getColorForLevel(level, widget.accentColor, isDark),
                  borderRadius: BorderRadius.circular(2.5),
                  border: Border.all(
                    color: level == 0
                        ? (isDark ? Colors.white12 : Colors.black12)
                        : Colors.transparent,
                    width: 0.8,
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
            Text(
              'Más',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Vista en Barras para 7D y 30D
  Widget _buildBarChart(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final isWeekly = widget.timeRange == StatsTimeRange.sevenDays;
    int maxCount = 0;
    for (final p in widget.series) {
      if (p.count > maxCount) maxCount = p.count;
    }
    if (maxCount < 1) maxCount = 1;

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: widget.series.map((point) {
          final isSelected = _selectedPoint == point;
          final heightFactor = (point.count / maxCount).clamp(0.06, 1.0);
          final level = _calculateLevel(point.count);
          final barColor = _getColorForLevel(level, widget.accentColor, isDark);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedPoint = isSelected ? null : point;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isWeekly ? 4.0 : 1.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Conteo flotante si es 7 días o si está seleccionado
                    if (isWeekly || isSelected)
                      Text(
                        '${point.count}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? widget.accentColor
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    const SizedBox(height: 4),

                    // Barra vertical animada
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: heightFactor,
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(isWeekly ? 6 : 3),
                            border: Border.all(
                              color: isSelected
                                  ? widget.accentColor
                                  : (level == 0
                                      ? (isDark ? Colors.white12 : Colors.black12)
                                      : Colors.transparent),
                              width: isSelected ? 1.6 : 0.8,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: widget.accentColor.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Etiqueta de día
                    Text(
                      isWeekly ? point.label : (point.date.day % 5 == 0 ? '${point.date.day}' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isWeekly ? 10.5 : 9,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected
                            ? widget.accentColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Vista en Matriz / Heatmap para 90D, 180D, 365D
  Widget _buildHeatmapGrid(BuildContext context, bool isDark) {
    // Agrupar en columnas semanales (7 filas: Lun a Dom)
    final points = widget.series;
    if (points.isEmpty) return const SizedBox();

    // Organizar por semanas
    final List<List<DailyDataPoint?>> weeks = [];
    List<DailyDataPoint?> currentWeek = List.filled(7, null);

    for (final p in points) {
      final dayIndex = p.date.weekday - 1; // 0: Lun, 6: Dom
      currentWeek[dayIndex] = p;

      if (dayIndex == 6) {
        weeks.add(currentWeek);
        currentWeek = List.filled(7, null);
      }
    }
    if (currentWeek.any((element) => element != null)) {
      weeks.add(currentWeek);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // Mostrar los días más recientes hacia la derecha
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiquetas de días de la semana a la izquierda
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((d) {
              return Container(
                height: 14,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              );
            }).toList(),
          ),

          // Columnas de semanas
          ...weeks.map((week) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: week.map((dayPoint) {
                if (dayPoint == null) {
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.all(1.5),
                  );
                }

                final isSelected = _selectedPoint == dayPoint;
                final level = _calculateLevel(dayPoint.count);
                final cellColor = _getColorForLevel(level, widget.accentColor, isDark);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedPoint = isSelected ? null : dayPoint;
                    });
                  },
                  child: Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isSelected
                            ? widget.accentColor
                            : (level == 0
                                ? (isDark ? Colors.white12 : Colors.black12)
                                : Colors.transparent),
                        width: isSelected ? 1.5 : 0.6,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: widget.accentColor.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  int _calculateLevel(int count) {
    if (count <= 0) return 0;
    if (count <= 2) return 1;
    if (count <= 4) return 2;
    if (count <= 6) return 3;
    return 4;
  }

  Color _getColorForLevel(int level, Color accent, bool isDark) {
    switch (level) {
      case 0:
        return isDark ? const Color(0xFF1B1D20) : const Color(0xFFE8ECEF);
      case 1:
        return accent.withValues(alpha: 0.30);
      case 2:
        return accent.withValues(alpha: 0.55);
      case 3:
        return accent.withValues(alpha: 0.80);
      case 4:
      default:
        return accent;
    }
  }

  String _formatPointDate(DateTime d) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }
}
