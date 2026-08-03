import 'dart:ui';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/habit.dart';
import '../constants/categories.dart';
import '../widgets/habit_streak_calendar.dart';

class CalendarStatsScreen extends StatefulWidget {
  final DateTime selectedDay;
  const CalendarStatsScreen({super.key, required this.selectedDay});

  @override
  State<CalendarStatsScreen> createState() => _CalendarStatsScreenState();
}

class _CalendarStatsScreenState extends State<CalendarStatsScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> _dayStatus = [];
  List<Habit> _habits = [];
  Habit? _selectedHabit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _dbHelper.getHabitsStatusForDate(widget.selectedDay);
    final habits = await _dbHelper.getAllHabits();
    if (!mounted) return;
    setState(() {
      _dayStatus = status;
      _habits = habits.where((h) => !h.isTask).toList();
    });
  }

  double get _dayPercent {
    final habitsOnly = _dayStatus.where((h) => h['isTask'] != true).toList();
    if (habitsOnly.isEmpty) return 0;
    final completedCount = habitsOnly.where((h) => h['completed'] == true).length;
    return completedCount / habitsOnly.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];

    return Scaffold(
      appBar: AppBar(title: Text('${widget.selectedDay.day}/${widget.selectedDay.month}/${widget.selectedDay.year}')),
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
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
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
                            Text('Cumplimiento del día', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
                            if (_dayStatus.where((h) => h['isTask'] != true).isNotEmpty)
                              Text('${(_dayPercent * 100).round()}%', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_dayStatus.isEmpty)
                          Text('Sin hábitos registrados este día.', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 13))
                        else
                          ..._dayStatus.map((h) {
                            final cat = kCategories[h['category']] ?? kCategories['general']!;
                            final completed = h['completed'] == true;
                            final isTask = h['isTask'] == true;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(cat['icon'] as IconData, size: 14, color: (cat['color'] as Color).withOpacity(0.9)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(h['name'] + (isTask ? '  ·  tarea' : ''),
                                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 13)),
                                  ),
                                  Icon(completed ? Icons.check_circle : Icons.cancel, size: 16,
                                      color: completed ? theme.colorScheme.primary : Colors.red.withOpacity(0.6)),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
              if (_habits.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Racha por hábito', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _habits.map((h) {
                      final accent = categoryAccent(context, h.category);
                      final selected = _selectedHabit?.id == h.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedHabit = selected ? null : h),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? accent.withOpacity(0.18) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? accent : Colors.transparent, width: 1.2),
                          ),
                          child: Text(h.name, style: TextStyle(color: selected ? accent : theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_selectedHabit != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
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
                        child: HabitStreakCalendar(habit: _selectedHabit!, accentColor: categoryAccent(context, _selectedHabit!.category)),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}