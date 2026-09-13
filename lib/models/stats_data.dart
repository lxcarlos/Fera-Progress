import 'package:flutter/foundation.dart';

enum StatsTimeRange {
  sevenDays,
  thirtyDays,
  threeMonths,
  sixMonths,
  oneYear,
}

extension StatsTimeRangeExt on StatsTimeRange {
  String get label {
    switch (this) {
      case StatsTimeRange.sevenDays:
        return '7 Días';
      case StatsTimeRange.thirtyDays:
        return '30 Días';
      case StatsTimeRange.threeMonths:
        return '3 Meses';
      case StatsTimeRange.sixMonths:
        return '6 Meses';
      case StatsTimeRange.oneYear:
        return '1 Año';
    }
  }

  String get shortLabel {
    switch (this) {
      case StatsTimeRange.sevenDays:
        return '7D';
      case StatsTimeRange.thirtyDays:
        return '30D';
      case StatsTimeRange.threeMonths:
        return '90D';
      case StatsTimeRange.sixMonths:
        return '180D';
      case StatsTimeRange.oneYear:
        return '1A';
    }
  }

  int get days {
    switch (this) {
      case StatsTimeRange.sevenDays:
        return 7;
      case StatsTimeRange.thirtyDays:
        return 30;
      case StatsTimeRange.threeMonths:
        return 90;
      case StatsTimeRange.sixMonths:
        return 180;
      case StatsTimeRange.oneYear:
        return 365;
    }
  }
}

@immutable
class DailyDataPoint {
  final DateTime date;
  final String label;
  final int count;
  final int previousCount;

  const DailyDataPoint({
    required this.date,
    required this.label,
    required this.count,
    this.previousCount = 0,
  });
}

@immutable
class CategoryStat {
  final String category;
  final int count;
  final double percentage; // 0.0 - 100.0

  const CategoryStat({
    required this.category,
    required this.count,
    required this.percentage,
  });
}

@immutable
class StatsDashboardData {
  final StatsTimeRange timeRange;
  final int totalCompleted;
  final int previousPeriodTotalCompleted;
  final double completionsChangePct;
  final double completionRate; // 0.0 a 1.0
  final double previousCompletionRate;
  final double completionRateChangePct;
  final int currentStreak;
  final int bestStreak;
  final int tasksCompleted;
  final int previousTasksCompleted;
  final int extraActivitiesCount;
  final int extraActivitiesPoints;
  final List<DailyDataPoint> trendSeries;
  final List<DailyDataPoint> consistencySeries;
  final List<CategoryStat> categoryBreakdown;
  final int activeHabitsCount;

  const StatsDashboardData({
    required this.timeRange,
    required this.totalCompleted,
    required this.previousPeriodTotalCompleted,
    required this.completionsChangePct,
    required this.completionRate,
    required this.previousCompletionRate,
    required this.completionRateChangePct,
    required this.currentStreak,
    required this.bestStreak,
    required this.tasksCompleted,
    required this.previousTasksCompleted,
    required this.extraActivitiesCount,
    required this.extraActivitiesPoints,
    required this.trendSeries,
    required this.consistencySeries,
    required this.categoryBreakdown,
    required this.activeHabitsCount,
  });
}
