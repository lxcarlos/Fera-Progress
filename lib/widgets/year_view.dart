import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/date_utils.dart';
import 'month_view.dart' show gridStartFor;

/// Vista de Año: SOLO para consultar. Muestra los 12 meses en miniatura con
/// un puntito de cumplimiento de hábitos por día. Tocar un mes te lleva a
/// la vista de Mes ya enfocada ahí (sigue siendo navegación, no edición).
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
    if (!mounted) return;
    setState(() {
      _completedDates = completed;
      _earliestHabitDate = earliest;
    });
  }

  String _key(DateTime d) => d.toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _year--)),
            GestureDetector(
              onTap: () => setState(() => _year = DateTime.now().year),
              child: Column(
                children: [
                  Text('$_year', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 16)),
                  if (_year != DateTime.now().year) Text('Toca para ir a este año', style: TextStyle(color: theme.colorScheme.primary, fontSize: 10)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _year++)),
          ],
        ),
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