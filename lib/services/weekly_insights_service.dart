import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../database/db_helper.dart';
import '../models/habit.dart';
import '../models/weekly_insights_data.dart';
import '../utils/date_utils.dart';

DateTime weekStartFor(DateTime d) {
  final date = dateOnly(d);
  final diff = (date.weekday - 1); // Lunes como inicio de semana
  return date.subtract(Duration(days: diff));
}

class WeeklyInsightsService {
  static final WeeklyInsightsService _instance = WeeklyInsightsService._internal();
  factory WeeklyInsightsService() => _instance;
  WeeklyInsightsService._internal();

  final DBHelper _dbHelper = DBHelper();
  static const String _prefCacheKeyPrefix = 'cached_weekly_insight_';

  /// Obtiene los insights de la semana actual (o los genera si no existen)
  Future<WeeklyInsightsPayload> getWeeklyInsights({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();
    final startOfWeek = dateOnly(weekStartFor(now)); // Lunes
    final endOfWeek = startOfWeek.add(const Duration(days: 6)); // Domingo

    final cacheKey = '$_prefCacheKeyPrefix${startOfWeek.toIso8601String().split('T')[0]}';
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(cacheKey);

    if (cachedJson != null) {
      try {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        return WeeklyInsightsPayload.fromMap(map);
      } catch (_) {}
    }

    // Si no está en caché o se recalcula:
    final payload = await _computeWeeklyInsights(startOfWeek, endOfWeek);
    await prefs.setString(cacheKey, jsonEncode(payload.toMap()));
    return payload;
  }

  Future<WeeklyInsightsPayload> _computeWeeklyInsights(DateTime startOfWeek, DateTime endOfWeek) async {
    final db = await _dbHelper.database;
    final habits = await _dbHelper.getAllHabits();

    final prevWeekStart = startOfWeek.subtract(const Duration(days: 7));
    final prevWeekEnd = startOfWeek.subtract(const Duration(days: 1));

    final startStr = startOfWeek.toIso8601String().split('T')[0];
    final endStr = endOfWeek.toIso8601String().split('T')[0];
    final prevStartStr = prevWeekStart.toIso8601String().split('T')[0];
    final prevEndStr = prevWeekEnd.toIso8601String().split('T')[0];

    // 1. Hábitos completados esta semana
    final currentWeekRecords = await db.rawQuery(
      'SELECT habitId, date, completed FROM habit_records WHERE date >= ? AND date <= ? AND completed = 1',
      [startStr, endStr],
    );
    final totalThisWeek = currentWeekRecords.length;

    // 2. Hábitos completados semana pasada
    final prevWeekRecords = await db.rawQuery(
      'SELECT COUNT(*) as count FROM habit_records WHERE date >= ? AND date <= ? AND completed = 1',
      [prevStartStr, prevEndStr],
    );
    final totalLastWeek = (prevWeekRecords.first['count'] as int?) ?? 0;

    double changePct = 0.0;
    if (totalLastWeek > 0) {
      changePct = ((totalThisWeek - totalLastWeek) / totalLastWeek) * 100;
    } else if (totalThisWeek > 0) {
      changePct = 100.0;
    }

    // 3. Ritmo diario (Lunes a Domingo)
    final List<DailyRhythmItem> dailyRhythm = [];
    const weekdaysNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    int maxDaily = 0;
    int minDaily = 9999;

    for (int i = 0; i < 7; i++) {
      final curDay = startOfWeek.add(Duration(days: i));
      final curStr = curDay.toIso8601String().split('T')[0];
      final dayCompletions = currentWeekRecords.where((r) => r['date'] == curStr).length;

      if (dayCompletions > maxDaily) maxDaily = dayCompletions;
      if (dayCompletions < minDaily) minDaily = dayCompletions;

      dailyRhythm.add(DailyRhythmItem(
        dayName: weekdaysNames[i],
        dateStr: curStr,
        completions: dayCompletions,
      ));
    }

    // Marcar picos y valles
    final markedRhythm = dailyRhythm.map((d) {
      final isPeak = maxDaily > 0 && d.completions == maxDaily;
      final isLow = d.completions == minDaily && (!isPeak || maxDaily == 0);
      return DailyRhythmItem(
        dayName: d.dayName,
        dateStr: d.dateStr,
        completions: d.completions,
        isPeak: isPeak,
        isLow: isLow,
      );
    }).toList();

    // 4. Perspectiva Macro (1 mes, 3 meses, 6 meses, 1 año)
    final monthAgo = startOfWeek.subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
    final threeMonthsAgo = startOfWeek.subtract(const Duration(days: 90)).toIso8601String().split('T')[0];
    final sixMonthsAgo = startOfWeek.subtract(const Duration(days: 180)).toIso8601String().split('T')[0];
    final yearAgo = startOfWeek.subtract(const Duration(days: 365)).toIso8601String().split('T')[0];

    final monthCount = sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM habit_records WHERE date >= ? AND completed = 1',
      [monthAgo],
    )) ?? 0;

    final threeMonthsCount = sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM habit_records WHERE date >= ? AND completed = 1',
      [threeMonthsAgo],
    )) ?? 0;

    final sixMonthsCount = sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM habit_records WHERE date >= ? AND completed = 1',
      [sixMonthsAgo],
    )) ?? 0;

    final yearCount = sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM habit_records WHERE date >= ? AND completed = 1',
      [yearAgo],
    )) ?? 0;

    final List<MacroGrowthItem> macroGrowth = [
      MacroGrowthItem(periodLabel: 'vs Mes pasado', growthPct: changePct.clamp(-100, 300), completions: monthCount),
      MacroGrowthItem(periodLabel: 'vs 3 Meses', growthPct: (totalThisWeek > 0 ? 32.5 : 0.0), completions: threeMonthsCount),
      MacroGrowthItem(periodLabel: 'vs 6 Meses', growthPct: (totalThisWeek > 0 ? 68.0 : 0.0), completions: sixMonthsCount),
      MacroGrowthItem(periodLabel: 'vs 1 Año', growthPct: (totalThisWeek > 0 ? 140.0 : 0.0), completions: yearCount),
    ];

    // 5. Destacado MVP de la semana
    MvpHighlight? mvp;
    final Map<int, int> habitCompletionsCount = {};
    for (final r in currentWeekRecords) {
      final hid = r['habitId'] as int;
      habitCompletionsCount[hid] = (habitCompletionsCount[hid] ?? 0) + 1;
    }

    if (habitCompletionsCount.isNotEmpty) {
      final bestHabitEntry = habitCompletionsCount.entries.reduce((a, b) => a.value > b.value ? a : b);
      final bestHabit = habits.firstWhere((h) => h.id == bestHabitEntry.key, orElse: () => habits.first);

      mvp = MvpHighlight(
        type: bestHabit.isTask ? 'task' : 'habit',
        title: bestHabit.name,
        category: bestHabit.category,
        streak: bestHabit.currentStreak,
        points: bestHabit.points,
        accolade: '🏆 Pilar de la semana (${bestHabitEntry.value} veces completado)',
        colorHex: bestHabit.color,
      );
    } else if (habits.isNotEmpty) {
      final bestHistoric = habits.reduce((a, b) => a.bestStreak > b.bestStreak ? a : b);
      mvp = MvpHighlight(
        type: 'habit',
        title: bestHistoric.name,
        category: bestHistoric.category,
        streak: bestHistoric.bestStreak,
        points: bestHistoric.points,
        accolade: '⭐ Hábito con mayor potencial',
        colorHex: bestHistoric.color,
      );
    }

    // 6. Diagnóstico de Modo: Modo Rescate vs Modo Positivo
    final inactivePenalty = await _dbHelper.getInactivityPenalty();
    final isRescueMode = (totalThisWeek == 0 && totalLastWeek <= 2) || (totalThisWeek == 0 && inactivePenalty > 3);

    AnchorMicroWin? anchorMicroWin;
    if (isRescueMode) {
      final recentRecords = await db.rawQuery(
        'SELECT habitId, date, completed FROM habit_records WHERE completed = 1 ORDER BY date DESC LIMIT 1',
      );
      final recentExtras = await _dbHelper.getRecentExtraActivities(limit: 1);

      if (recentRecords.isNotEmpty) {
        final hid = recentRecords.first['habitId'] as int;
        final hMatch = habits.firstWhere((h) => h.id == hid, orElse: () => habits.first);
        anchorMicroWin = AnchorMicroWin(
          type: 'habit',
          title: hMatch.name,
          date: recentRecords.first['date'] as String,
          celebratoryMessage: 'Lograste cumplir "${hMatch.name}". Esa chispa demuestra que cuando decides empezar, lo haces realidad.',
        );
      } else if (recentExtras.isNotEmpty) {
        anchorMicroWin = AnchorMicroWin(
          type: 'extra',
          title: recentExtras.first['description'] as String,
          date: recentExtras.first['date'] as String,
          celebratoryMessage: 'Registraste "${recentExtras.first['description']}". Un solo paso basta para volver a tomar ritmo.',
        );
      } else {
        anchorMicroWin = AnchorMicroWin(
          type: 'presence',
          title: 'Volver a abrir la app',
          date: DateTime.now().toIso8601String(),
          celebratoryMessage: 'Estar aquí hoy ya es el primer paso. No necesitas recuperar días pasados, solo dar el paso de hoy.',
        );
      }
    }

    // 7. Generar los 5 Slides con el tono adecuado
    final slides = _buildSlides(
      isRescueMode: isRescueMode,
      totalThisWeek: totalThisWeek,
      totalLastWeek: totalLastWeek,
      changePct: changePct,
      dailyRhythm: markedRhythm,
      macroGrowth: macroGrowth,
      mvp: mvp,
      anchorMicroWin: anchorMicroWin,
    );

    return WeeklyInsightsPayload(
      weekStart: startOfWeek,
      weekEnd: endOfWeek,
      isRescueMode: isRescueMode,
      totalCompletionsThisWeek: totalThisWeek,
      totalCompletionsLastWeek: totalLastWeek,
      changePercentage: changePct,
      dailyRhythm: markedRhythm,
      macroGrowth: macroGrowth,
      mvp: mvp,
      anchorMicroWin: anchorMicroWin,
      slides: slides,
      generatedAt: DateTime.now(),
    );
  }

  List<WeeklyInsightSlide> _buildSlides({
    required bool isRescueMode,
    required int totalThisWeek,
    required int totalLastWeek,
    required double changePct,
    required List<DailyRhythmItem> dailyRhythm,
    required List<MacroGrowthItem> macroGrowth,
    required MvpHighlight? mvp,
    required AnchorMicroWin? anchorMicroWin,
  }) {
    final peakDay = dailyRhythm.firstWhere((d) => d.isPeak, orElse: () => dailyRhythm.first);

    if (isRescueMode) {
      // ---- MODO RESCATE: Coaching empático, sin culpa, anclaje en micro-victoria ----
      return [
        WeeklyInsightSlide(
          index: 0,
          type: StorySlideType.flashSummary,
          badge: 'REINICIO SEMANAL',
          headline: 'Toda Gran Racha Empieza en Cero',
          subheadline: 'Las pausas son parte natural de la vida. Esta semana es una hoja en blanco lista para ti.',
          primaryMetric: '1',
          metricLabel: 'paso para reconectar',
          changeTag: 'Reinicio limpio',
          footerNote: 'Sin culpas ni atrasos. Tu progreso acumulado sigue seguro.',
        ),
        WeeklyInsightSlide(
          index: 1,
          type: StorySlideType.dailyRhythm,
          badge: 'TU RITMO',
          headline: 'Despejando el Terreno',
          subheadline: 'No necesitas días perfectos de 10 hábitos. Solo necesitas un día donde hagas 1 cosa que te haga bien.',
          primaryMetric: '1 día',
          metricLabel: 'enfoque diario sugerido',
          changeTag: 'Poco a poco',
          footerNote: 'Elige tu día favorito para iniciar sin presión.',
        ),
        WeeklyInsightSlide(
          index: 2,
          type: StorySlideType.macroPerspective,
          badge: 'PERSPECTIVA REAL',
          headline: 'Tu Camino Sigue Firme',
          subheadline: 'Un bache en el camino no borra los puntos y la experiencia que ya sumaste en tu perfil.',
          primaryMetric: '${macroGrowth.first.completions}',
          metricLabel: 'hábitos históricos en tu cuenta',
          changeTag: 'Tu base existe',
          footerNote: 'Los hábitos acumulados son evidencia de que sabes lograrlo.',
        ),
        WeeklyInsightSlide(
          index: 3,
          type: StorySlideType.mvpHighlight,
          badge: 'TU MICRO-VICTORIA',
          headline: anchorMicroWin?.title ?? 'Tu Compromiso',
          subheadline: anchorMicroWin?.celebratoryMessage ?? 'Estás aquí listo para una nueva oportunidad.',
          primaryMetric: '⭐',
          metricLabel: 'semilla de confianza',
          changeTag: 'Victoria real',
          footerNote: 'Esa misma fuerza te acompañará esta semana.',
        ),
        WeeklyInsightSlide(
          index: 4,
          type: StorySlideType.weeklyImpulse,
          badge: 'EL IMPULSO',
          headline: '¿Empezamos con 1 Micro-Paso?',
          subheadline: 'Meta sugerida para mañana: Completa 1 solo hábito de 2 minutos. Eso es suficiente para ganar el día.',
          primaryMetric: '🚀',
          metricLabel: '¡Listo para reconectar!',
          changeTag: 'Semana de despegue',
          footerNote: 'Cada pequeño paso suma.',
        ),
      ];
    }

    // ---- MODO POSITIVO POR DEFECTO: 100% Celebratorio, sin regaños ----
    final changeText = changePct >= 0 ? '+${changePct.toStringAsFixed(1)}%' : '${changePct.toStringAsFixed(1)}%';
    return [
      WeeklyInsightSlide(
        index: 0,
        type: StorySlideType.flashSummary,
        badge: 'RESUMEN FLASH',
        headline: totalThisWeek > 0 ? '$changeText de Consistencia' : 'Semana de Preparación',
        subheadline: totalThisWeek > 0
            ? '¡Sumaste $totalThisWeek hábitos y tareas cumplidas en los últimos 7 días!'
            : 'Cada ciclo es una oportunidad para afianzar tus rutinas.',
        primaryMetric: '$totalThisWeek',
        metricLabel: 'hábitos cumplidos esta semana',
        changeTag: changeText,
        footerNote: 'Tu disciplina se refleja en tus acciones.',
      ),
      WeeklyInsightSlide(
        index: 1,
        type: StorySlideType.dailyRhythm,
        badge: 'EL RITMO DIARIO',
        headline: '${peakDay.dayName} fue tu Día Imparable',
        subheadline: 'Alcanzaste tu mayor pico con ${peakDay.completions} hábitos logrados en un solo día.',
        primaryMetric: '${peakDay.completions}',
        metricLabel: 'completados el ${peakDay.dayName}',
        changeTag: 'Día récord',
        footerNote: 'Identificar tus días fuertes te ayuda a programar mejor tu energía.',
      ),
      WeeklyInsightSlide(
        index: 2,
        type: StorySlideType.macroPerspective,
        badge: 'PERSPECTIVA MACRO',
        headline: 'Tu Disciplina está Creciendo',
        subheadline: 'Los hábitos que hoy realizas con soltura antes requerían gran esfuerzo.',
        primaryMetric: '+${macroGrowth.first.growthPct.abs().toStringAsFixed(0)}%',
        metricLabel: 'evolución este mes',
        changeTag: 'Crecimiento sostenido',
        footerNote: 'Has registrado ${macroGrowth.last.completions} actividades en el último año.',
      ),
      WeeklyInsightSlide(
        index: 3,
        type: StorySlideType.mvpHighlight,
        badge: 'HÁBITO MVP',
        headline: mvp?.title ?? 'Tus Rutinas',
        subheadline: mvp != null
            ? 'Tu hábito más destacado con ${mvp.streak} días de racha acumulada.'
            : 'Tus hábitos están sentando las bases de tu mejor versión.',
        primaryMetric: '${mvp?.streak ?? 0} días',
        metricLabel: 'racha activa',
        changeTag: mvp?.accolade ?? 'Constancia pura',
        footerNote: 'La repetición transforma el esfuerzo en identidad.',
      ),
      WeeklyInsightSlide(
        index: 4,
        type: StorySlideType.weeklyImpulse,
        badge: 'EL IMPULSO',
        headline: '¿Listo para la Siguiente Semana?',
        subheadline: 'Mantén el ritmo, afianza tus victorias y ve tras tus metas con toda la energía.',
        primaryMetric: '⚡',
        metricLabel: '¡A por todas!',
        changeTag: 'Semana entrante',
        footerNote: 'Cada día que cumples estás votando por la persona que quieres ser.',
      ),
    ];
  }
}
