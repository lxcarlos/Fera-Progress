import 'dart:math';
import '../database/db_helper.dart';
import '../models/stats_data.dart';
import '../utils/date_utils.dart';

class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  final DBHelper _dbHelper = DBHelper();

  /// Obtiene los datos de estadísticas para el rango temporal seleccionado.
  Future<StatsDashboardData> getDashboardStats(StatsTimeRange range) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final today = dateOnly(now);
    final days = range.days;

    // Rango actual: [startCurrent, today]
    final startCurrent = today.subtract(Duration(days: days - 1));
    final endCurrent = today;

    // Rango anterior: [startPrevious, endPrevious]
    final startPrevious = startCurrent.subtract(Duration(days: days));
    final endPrevious = startCurrent.subtract(const Duration(days: 1));

    final startCurrentStr = startCurrent.toIso8601String().split('T')[0];
    final endCurrentStr = endCurrent.toIso8601String().split('T')[0];
    final startPrevStr = startPrevious.toIso8601String().split('T')[0];
    final endPrevStr = endPrevious.toIso8601String().split('T')[0];

    // 1. Obtener hábitos y tareas
    final habitsRaw = await db.query('habits');
    final Map<int, Map<String, dynamic>> habitsMap = {
      for (final h in habitsRaw) (h['id'] as int): h
    };

    final habitIds = <int>{};
    final taskIds = <int>{};
    int maxBestStreak = 0;
    int maxCurrentStreak = 0;

    for (final h in habitsRaw) {
      final id = h['id'] as int;
      final isTask = (h['isTask'] as int? ?? 0) == 1;
      if (isTask) {
        taskIds.add(id);
      } else {
        habitIds.add(id);
        final bStreak = (h['bestStreak'] as int? ?? 0);
        final cStreak = (h['currentStreak'] as int? ?? 0);
        if (bStreak > maxBestStreak) maxBestStreak = bStreak;
        if (cStreak > maxCurrentStreak) maxCurrentStreak = cStreak;
      }
    }

    // 2. Registros del período actual
    final currentRecords = await db.rawQuery(
      'SELECT habitId, date, completed FROM habit_records WHERE date >= ? AND date <= ? AND completed = 1',
      [startCurrentStr, endCurrentStr],
    );

    // 3. Registros del período anterior
    final prevRecords = await db.rawQuery(
      'SELECT habitId, date, completed FROM habit_records WHERE date >= ? AND date <= ? AND completed = 1',
      [startPrevStr, endPrevStr],
    );

    // Separar hábitos de tareas
    final currentHabitRecords = currentRecords.where((r) => habitIds.contains(r['habitId'] as int)).toList();
    final currentTaskRecords = currentRecords.where((r) => taskIds.contains(r['habitId'] as int)).toList();

    final prevHabitRecords = prevRecords.where((r) => habitIds.contains(r['habitId'] as int)).toList();
    final prevTaskRecords = prevRecords.where((r) => taskIds.contains(r['habitId'] as int)).toList();

    final totalCompleted = currentHabitRecords.length;
    final prevTotalCompleted = prevHabitRecords.length;

    // Delta porcentual de completados
    double completionsChangePct = 0.0;
    if (prevTotalCompleted > 0) {
      completionsChangePct = ((totalCompleted - prevTotalCompleted) / prevTotalCompleted) * 100.0;
    } else if (totalCompleted > 0) {
      completionsChangePct = 100.0;
    }

    // Tasa de cumplimiento (% de completitud esperada)
    final activeHabitsCount = max(habitIds.length, 1);
    final expectedPossible = activeHabitsCount * days;
    final completionRate = (totalCompleted / expectedPossible).clamp(0.0, 1.0);

    final prevCompletionRate = (prevTotalCompleted / expectedPossible).clamp(0.0, 1.0);
    final completionRateChangePct = (completionRate - prevCompletionRate) * 100.0;

    // 4. Actividades extra
    final extraStartIso = '${startCurrentStr}T00:00:00.000';
    final extraEndIso = '${endCurrentStr}T23:59:59.999';
    final extraActivitiesRaw = await db.rawQuery(
      'SELECT points FROM extra_activities WHERE date >= ? AND date <= ?',
      [extraStartIso, extraEndIso],
    );
    final extraActivitiesCount = extraActivitiesRaw.length;
    int extraActivitiesPoints = 0;
    for (final e in extraActivitiesRaw) {
      extraActivitiesPoints += (e['points'] as int? ?? 0);
    }

    // 5. Agrupación por día para series de consistencia y tendencia
    final Map<String, int> curCompletionsByDate = {};
    for (final r in currentHabitRecords) {
      final d = r['date'] as String;
      curCompletionsByDate[d] = (curCompletionsByDate[d] ?? 0) + 1;
    }

    final Map<String, int> prevCompletionsByDate = {};
    for (final r in prevHabitRecords) {
      final d = r['date'] as String;
      prevCompletionsByDate[d] = (prevCompletionsByDate[d] ?? 0) + 1;
    }

    final List<DailyDataPoint> consistencySeries = [];
    const weekdaysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    for (int i = 0; i < days; i++) {
      final curD = startCurrent.add(Duration(days: i));
      final curStr = curD.toIso8601String().split('T')[0];
      final prevD = startPrevious.add(Duration(days: i));
      final prevStr = prevD.toIso8601String().split('T')[0];

      final countCur = curCompletionsByDate[curStr] ?? 0;
      final countPrev = prevCompletionsByDate[prevStr] ?? 0;

      String label;
      if (days <= 7) {
        label = weekdaysShort[curD.weekday - 1];
      } else {
        label = '${curD.day}/${curD.month}';
      }

      consistencySeries.add(DailyDataPoint(
        date: curD,
        label: label,
        count: countCur,
        previousCount: countPrev,
      ));
    }

    // 6. Generar Trend Series (curva spline adaptada a la escala de tiempo)
    List<DailyDataPoint> trendSeries = [];
    if (days <= 30) {
      trendSeries = List.from(consistencySeries);
    } else if (days <= 90) {
      // Agrupar cada 3 días para suavizado óptimo (~30 puntos)
      trendSeries = _aggregateDataPoints(consistencySeries, 3);
    } else if (days <= 180) {
      // Agrupar cada 7 días (semanal, ~26 puntos)
      trendSeries = _aggregateDataPoints(consistencySeries, 7);
    } else {
      // 365 días: agrupar cada 7 o 14 días (~26 - 52 puntos)
      trendSeries = _aggregateDataPoints(consistencySeries, 7);
    }

    // 7. Desglose por categorías
    final Map<String, int> categoryCounts = {};
    for (final r in currentHabitRecords) {
      final habitId = r['habitId'] as int;
      final habitData = habitsMap[habitId];
      final cat = (habitData?['category'] as String?) ?? 'general';
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final List<CategoryStat> categoryBreakdown = [];
    if (totalCompleted > 0) {
      categoryCounts.forEach((cat, count) {
        final pct = (count / totalCompleted) * 100.0;
        categoryBreakdown.add(CategoryStat(
          category: cat,
          count: count,
          percentage: pct,
        ));
      });
      categoryBreakdown.sort((a, b) => b.count.compareTo(a.count));
    }

    return StatsDashboardData(
      timeRange: range,
      totalCompleted: totalCompleted,
      previousPeriodTotalCompleted: prevTotalCompleted,
      completionsChangePct: completionsChangePct,
      completionRate: completionRate,
      previousCompletionRate: prevCompletionRate,
      completionRateChangePct: completionRateChangePct,
      currentStreak: maxCurrentStreak,
      bestStreak: maxBestStreak,
      tasksCompleted: currentTaskRecords.length,
      previousTasksCompleted: prevTaskRecords.length,
      extraActivitiesCount: extraActivitiesCount,
      extraActivitiesPoints: extraActivitiesPoints,
      trendSeries: trendSeries,
      consistencySeries: consistencySeries,
      categoryBreakdown: categoryBreakdown,
      activeHabitsCount: habitIds.length,
    );
  }

  /// Agrupa puntos diarios en bloques de tamaño [chunkSize] para curvas suaves.
  List<DailyDataPoint> _aggregateDataPoints(List<DailyDataPoint> points, int chunkSize) {
    final List<DailyDataPoint> aggregated = [];
    for (int i = 0; i < points.length; i += chunkSize) {
      final end = min(i + chunkSize, points.length);
      final sub = points.sublist(i, end);

      int sumCur = 0;
      int sumPrev = 0;
      for (final p in sub) {
        sumCur += p.count;
        sumPrev += p.previousCount;
      }

      final midPoint = sub[sub.length ~/ 2];
      aggregated.add(DailyDataPoint(
        date: midPoint.date,
        label: '${midPoint.date.day}/${midPoint.date.month}',
        count: sumCur,
        previousCount: sumPrev,
      ));
    }
    return aggregated;
  }
}
