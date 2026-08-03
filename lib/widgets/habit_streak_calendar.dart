import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/db_helper.dart';
import '../models/habit.dart';
import '../utils/date_utils.dart';

class HabitStreakCalendar extends StatefulWidget {
  final Habit habit;
  final Color accentColor;
  const HabitStreakCalendar({super.key, required this.habit, required this.accentColor});

  @override
  State<HabitStreakCalendar> createState() => _HabitStreakCalendarState();
}

class _HabitStreakCalendarState extends State<HabitStreakCalendar> {
  final DBHelper _dbHelper = DBHelper();
  Set<String> _completedDates = {};
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HabitStreakCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habit.id != widget.habit.id) _load();
  }

  Future<void> _load() async {
    if (widget.habit.id == null) return;
    final dates = await _dbHelper.getCompletedDatesForHabit(widget.habit.id!);
    if (!mounted) return;
    setState(() => _completedDates = dates);
  }

  String _dateKey(DateTime day) => dateOnly(day).toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _stat('${widget.habit.currentStreak}', 'Racha actual', widget.accentColor, theme),
            _stat('${widget.habit.bestStreak}', 'Mejor racha', theme.colorScheme.onSurface, theme),
            _stat('${_completedDates.length}', 'Total cumplidos', theme.colorScheme.onSurface, theme),
          ],
        ),
        const SizedBox(height: 16),
        TableCalendar(
          firstDay: widget.habit.createdAt,
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          onPageChanged: (day) => setState(() => _focusedDay = day),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleTextStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
            leftChevronIcon: Icon(Icons.chevron_left, color: theme.colorScheme.onSurface.withOpacity(0.7)),
            rightChevronIcon: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 11),
            weekendStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 11),
          ),
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
          calendarStyle: CalendarStyle(
            outsideTextStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.2)),
            defaultTextStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.75)),
            weekendTextStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.75)),
            todayDecoration: BoxDecoration(border: Border.all(color: widget.accentColor, width: 1.4), shape: BoxShape.circle),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              if (_completedDates.contains(_dateKey(day))) {
                return Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${day.day}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }
}