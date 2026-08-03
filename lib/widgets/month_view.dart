import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../constants/categories.dart';
import '../utils/date_utils.dart';
import '../utils/recurrence_utils.dart';

const List<String> kWeekdayShortMonth = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

DateTime gridStartFor(DateTime month) {
  final firstOfMonth = DateTime(month.year, month.month, 1);
  final startWeekday = firstOfMonth.weekday % 7; // domingo -> 0
  return firstOfMonth.subtract(Duration(days: startWeekday));
}

/// Vista de Mes: SOLO para consultar (no crea ni edita eventos aquí).
/// Al tocar un día se muestra, debajo de la cuadrícula, una lista de solo
/// lectura con los eventos de ese día. El botón "Ver/editar" manda a la
/// vista de Día ya enfocada en esa fecha, que es donde sí se puede editar.
class MonthView extends StatefulWidget {
  final DateTime anchorDate;
  final ValueChanged<DateTime>? onEditDay;
  const MonthView({super.key, required this.anchorDate, this.onEditDay});

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  final DBHelper _dbHelper = DBHelper();
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  Set<String> _completedDates = {};
  DateTime? _earliestHabitDate;
  Map<String, List<CalendarEvent>> _eventsByDate = {};

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.anchorDate.year, widget.anchorDate.month, 1);
    _selectedDay = dateOnly(widget.anchorDate);
    _load();
  }

  String _key(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> _load() async {
    final completed = await _dbHelper.getCompletedDates();
    final earliest = await _dbHelper.getEarliestHabitDate();
    final allEvents = await _dbHelper.getAllEvents();

    final Map<String, List<CalendarEvent>> byDate = {};
    final start = gridStartFor(_focusedMonth);
    for (int i = 0; i < 42; i++) {
      final day = start.add(Duration(days: i));
      final matches = allEvents.where((e) => eventOccursOnDate(e, day)).toList();
      if (matches.isNotEmpty) byDate[_key(day)] = matches;
    }

    if (!mounted) return;
    setState(() {
      _completedDates = completed;
      _earliestHabitDate = earliest;
      _eventsByDate = byDate;
    });
  }

  void _changeMonth(int delta) {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gridStart = gridStartFor(_focusedMonth);
    final selectedEvents = _eventsByDate[_key(_selectedDay)] ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
            Text(
              '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
          ],
        ),
        Row(
          children: kWeekdayShortMonth
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4))),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.95,
          children: List.generate(42, (i) {
            final day = gridStart.add(Duration(days: i));
            final inMonth = day.month == _focusedMonth.month;
            final isToday = isSameDate(day, DateTime.now());
            final isSelected = isSameDate(day, _selectedDay);
            final key = _key(day);
            final hasEvents = _eventsByDate.containsKey(key);
            final isCompleted = _completedDates.contains(key);
            final isPast = day.isBefore(DateTime.now());
            final hasHabitsYet = _earliestHabitDate != null && !day.isBefore(_earliestHabitDate!);
            final showHabitDot = isCompleted || (isPast && hasHabitsYet && !isToday);

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = dateOnly(day)),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday ? Border.all(color: theme.colorScheme.primary.withOpacity(0.6)) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: inMonth ? theme.colorScheme.onSurface.withOpacity(0.85) : theme.colorScheme.onSurface.withOpacity(0.25),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showHabitDot)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: isCompleted ? theme.colorScheme.primary : Colors.red.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (hasEvents)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Eventos del ${_selectedDay.day} de ${_monthName(_selectedDay.month)}',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () => widget.onEditDay?.call(_selectedDay),
                child: const Text('Ver / editar'),
              ),
            ],
          ),
        ),
        if (selectedEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Sin eventos este día.', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
          )
        else
          ...selectedEvents.map((e) {
            final color = categoryAccent(context, e.category);
            final catData = kCategories[e.category] ?? kCategories['general']!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(catData['icon'] as IconData, size: 13, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.title, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.85), fontSize: 13))),
                  Text(e.startTime + (e.endTime != null ? ' - ${e.endTime}' : ''),
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.45), fontSize: 11)),
                ],
              ),
            );
          }),
      ],
    );
  }

  static const List<String> _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  String _monthName(int m) => _months[m - 1];
}