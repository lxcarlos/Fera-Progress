import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/db_helper.dart';
import '../widgets/day_agenda.dart';
import 'calendar_stats_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  final DBHelper _dbHelper = DBHelper();
  Set<String> _completedDates = {};
  DateTime? _earliestDate;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  double _dayPercent = 0;
  bool _hasHabitsToday = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final completed = await _dbHelper.getCompletedDates();
    final earliest = await _dbHelper.getEarliestHabitDate();
    await _loadDayPercent(_selectedDay);
    if (!mounted) return;
    setState(() {
      _completedDates = completed;
      _earliestDate = earliest;
    });
  }

  Future<void> _loadDayPercent(DateTime day) async {
    final status = await _dbHelper.getHabitsStatusForDate(day);
    final habitsOnly = status.where((h) => h['isTask'] != true).toList();
    if (!mounted) return;
    setState(() {
      _hasHabitsToday = habitsOnly.isNotEmpty;
      _dayPercent = habitsOnly.isEmpty ? 0 : habitsOnly.where((h) => h['completed'] == true).length / habitsOnly.length;
    });
  }

  String _dateKey(DateTime day) => day.toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Calendario', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: refresh),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        TableCalendar(
                          firstDay: _earliestDate ?? DateTime.now().subtract(const Duration(days: 365)),
                          lastDay: DateTime.now().add(const Duration(days: 365)),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selected, focused) {
                            setState(() {
                              _selectedDay = selected;
                              _focusedDay = focused;
                            });
                            _loadDayPercent(selected);
                          },
                          calendarFormat: CalendarFormat.month,
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleTextStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
                            leftChevronIcon: Icon(Icons.chevron_left, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                            rightChevronIcon: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            weekendStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                          ),
                          calendarStyle: CalendarStyle(
                            defaultTextStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
                            weekendTextStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
                            todayDecoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.35), shape: BoxShape.circle),
                            selectedDecoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                            outsideTextStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.2)),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              final key = _dateKey(day);
                              final isCompleted = _completedDates.contains(key);
                              final isPast = day.isBefore(DateTime.now());
                              final hasHabitsYet = _earliestDate != null && !day.isBefore(_earliestDate!);

                              if (isCompleted) {
                                return Positioned(
                                  bottom: 4,
                                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
                                );
                              } else if (isPast && hasHabitsYet && !isSameDay(day, DateTime.now())) {
                                return Positioned(
                                  bottom: 4,
                                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.red.withOpacity(0.6), shape: BoxShape.circle)),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legendDot(theme.colorScheme.primary, 'Cumplido', theme),
                            const SizedBox(width: 20),
                            _legendDot(Colors.red.withOpacity(0.6), 'No cumplido', theme),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarStatsScreen(selectedDay: _selectedDay))).then((_) => refresh()),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
                              Row(
                                children: [
                                  if (_hasHabitsToday)
                                    Text('${(_dayPercent * 100).round()}%', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _hasHabitsToday ? _dayPercent : 0,
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.onSurface.withOpacity(0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Toca para ver el detalle y la racha por hábito', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Agenda del día', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                    ),
                    child: DayAgenda(date: _selectedDay, onChanged: refresh),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
      ],
    );
  }
}