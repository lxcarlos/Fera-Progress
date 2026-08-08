import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/date_utils.dart';
import 'month_view.dart' show gridStartFor;
import 'year_heatmap.dart';

/// Vista de Año: SOLO para consultar. Muestra un heatmap estilo GitHub de
/// todo el año, y debajo los 12 meses en miniatura con un puntito de
/// cumplimiento de hábitos por día. Tocar un mes te lleva a la vista de
/// Mes ya enfocada ahí (sigue siendo navegación, no edición).
class YearView extends StatefulWidget {
  final DateTime anchorDate;
  final ValueChanged<DateTime>? onOpenMonth;
  const YearView({super.key, required this.anchorDate, this.onOpenMonth});

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  final DBHelper _dbHelper = DBHelper();
  late int _year;
  Set<String> _completedDates = {};
  Map<String, int> _completionCounts = {};
  DateTime? _earliestHabitDate;

  static const List<String> _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.anchorDate.year;
    _load();
  }

  Future<void> _load() async {
    final completed = await _dbHelper.getCompletedDates();
    final earliest = await _dbHelper.getEarliestHabitDate();
    final counts = await _dbHelper.getCompletionCountsByYear(_year);
    if (!mounted) return;
    setState(() {
      _completedDates = completed;
      _earliestHabitDate = earliest;
      _completionCounts = counts;
    });
  }

  String _key(DateTime d) => d.toIso8601String().split('T')[0];

  /// "298/365": qué tan avanzado va el año, contando desde el 1 de enero
  /// hasta hoy. Solo tiene sentido mostrarlo para el año actual.
  String? _yearProgressLabel() {
    final now = DateTime.now();
    if (_year != now.year) return null;
    final jan1 = DateTime(_year, 1, 1);
    final dayOfYear = now.difference(jan1).inDays + 1;
    final isLeap = (_year % 4 == 0 && _year % 100 != 0) || (_year % 400 == 0);
    final totalDays = isLeap ? 366 : 365;
    return '$dayOfYear/$totalDays';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _yearProgressLabel();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [


            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _year--);
                _load();
              },
            ),


            GestureDetector(
              onTap: () => setState(() => _year = DateTime.now().year),
              child: Column(
                children: [
                  Text('$_year', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 16)),
                  if (_year != DateTime.now().year) Text('Toca para ir a este año', style: TextStyle(color: theme.colorScheme.primary, fontSize: 10)),
                ],
              ),
            ),


            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() => _year++);
                _load();
              },
            ),



          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 2),
          Text(
            'Día $progress del año',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],
        YearHeatmap(year: _year, countsByDate: _completionCounts),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.95,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = DateTime(_year, index + 1, 1);
              return GestureDetector(
                onTap: () => widget.onOpenMonth?.call(month),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      Text(_months[index], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.7))),
                      const SizedBox(height: 4),
                      Expanded(child: _MiniMonthGrid(month: month, completedDates: _completedDates, earliestHabitDate: _earliestHabitDate)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniMonthGrid extends StatelessWidget {
  final DateTime month;
  final Set<String> completedDates;
  final DateTime? earliestHabitDate;

  const _MiniMonthGrid({required this.month, required this.completedDates, required this.earliestHabitDate});

  String _key(DateTime d) => d.toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = gridStartFor(month);
    final now = DateTime.now();

    return GridView.count(
      crossAxisCount: 7,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      children: List.generate(42, (i) {
        final day = start.add(Duration(days: i));
        final inMonth = day.month == month.month;
        if (!inMonth) return const SizedBox();

        final key = _key(day);
        final isToday = isSameDate(day, now);
        final isCompleted = completedDates.contains(key);
        final isPast = day.isBefore(now);
        final hasHabitsYet = earliestHabitDate != null && !day.isBefore(earliestHabitDate!);
        final showDot = isCompleted || (isPast && hasHabitsYet && !isToday);

        return Center(
          child: Container(
            width: 12,
            height: 12,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isToday ? Border.all(color: theme.colorScheme.primary, width: 1) : null,
            ),
            child: showDot
                ? Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted ? theme.colorScheme.primary : Colors.red.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  )
                : Text('${day.day}', style: TextStyle(fontSize: 6, color: theme.colorScheme.onSurface.withOpacity(0.35))),
          ),
        );
      }),
    );
  }
}