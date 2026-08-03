import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../constants/categories.dart';
import '../widgets/habit_streak_calendar.dart';

class HabitHistoryScreen extends StatelessWidget {
  final Habit habit;
  const HabitHistoryScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];
    final catData = kCategories[habit.category] ?? kCategories['general']!;
    final accent = categoryAccent(context, habit.category);

    return Scaffold(
      appBar: AppBar(title: Text(habit.name)),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Icon(catData['icon'] as IconData, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text(catData['label'] as String, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                ],
              ),
              const SizedBox(height: 16),
              HabitStreakCalendar(habit: habit, accentColor: accent),
            ],
          ),
        ),
      ),
    );
  }
}