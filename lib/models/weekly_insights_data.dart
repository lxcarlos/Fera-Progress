import 'package:flutter/material.dart';

/// Punto de ritmo diario (Lunes a Domingo)
class DailyRhythmItem {
  final String dayName;
  final String dateStr;
  final int completions;
  final bool isPeak;
  final bool isLow;

  DailyRhythmItem({
    required this.dayName,
    required this.dateStr,
    required this.completions,
    this.isPeak = false,
    this.isLow = false,
  });

  Map<String, dynamic> toMap() => {
        'day': dayName,
        'date': dateStr,
        'completions': completions,
        'is_peak': isPeak,
        'is_low': isLow,
      };

  factory DailyRhythmItem.fromMap(Map<String, dynamic> map) => DailyRhythmItem(
        dayName: map['day'] ?? '',
        dateStr: map['date'] ?? '',
        completions: (map['completions'] as num?)?.toInt() ?? 0,
        isPeak: map['is_peak'] == true,
        isLow: map['is_low'] == true,
      );
}

/// Comparativa de crecimiento macro temporal
class MacroGrowthItem {
  final String periodLabel;
  final double growthPct;
  final int completions;

  MacroGrowthItem({
    required this.periodLabel,
    required this.growthPct,
    required this.completions,
  });

  Map<String, dynamic> toMap() => {
        'period': periodLabel,
        'growth_pct': growthPct,
        'completions': completions,
      };

  factory MacroGrowthItem.fromMap(Map<String, dynamic> map) => MacroGrowthItem(
        periodLabel: map['period'] ?? '',
        growthPct: (map['growth_pct'] as num?)?.toDouble() ?? 0.0,
        completions: (map['completions'] as num?)?.toInt() ?? 0,
      );
}

/// Destacado MVP de la semana
class MvpHighlight {
  final String type; // 'habit', 'task', 'extra'
  final String title;
  final String category;
  final int streak;
  final int points;
  final String accolade;
  final String? colorHex;

  MvpHighlight({
    required this.type,
    required this.title,
    required this.category,
    this.streak = 0,
    this.points = 0,
    required this.accolade,
    this.colorHex,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'category': category,
        'streak': streak,
        'points': points,
        'accolade': accolade,
        'color_hex': colorHex,
      };

  factory MvpHighlight.fromMap(Map<String, dynamic> map) => MvpHighlight(
        type: map['type'] ?? 'habit',
        title: map['title'] ?? '',
        category: map['category'] ?? 'general',
        streak: (map['streak'] as num?)?.toInt() ?? 0,
        points: (map['points'] as num?)?.toInt() ?? 0,
        accolade: map['accolade'] ?? 'Destacado de la semana',
        colorHex: map['color_hex'],
      );
}

/// Victoria de anclaje para el Modo Rescate
class AnchorMicroWin {
  final String type;
  final String title;
  final String date;
  final String celebratoryMessage;

  AnchorMicroWin({
    required this.type,
    required this.title,
    required this.date,
    required this.celebratoryMessage,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'date': date,
        'celebratory_message': celebratoryMessage,
      };

  factory AnchorMicroWin.fromMap(Map<String, dynamic> map) => AnchorMicroWin(
        type: map['type'] ?? 'presence',
        title: map['title'] ?? '',
        date: map['date'] ?? '',
        celebratoryMessage: map['celebratory_message'] ?? '',
      );
}

/// Tipo de historia individual
enum StorySlideType {
  flashSummary,
  dailyRhythm,
  macroPerspective,
  mvpHighlight,
  weeklyImpulse,
}

/// Modelo de datos para renderizar cada una de las 5 Stories
class WeeklyInsightSlide {
  final int index;
  final StorySlideType type;
  final String badge;
  final String headline;
  final String subheadline;
  final String? primaryMetric;
  final String? metricLabel;
  final String? changeTag;
  final String? footerNote;
  final List<dynamic>? chartData;
  final Map<String, dynamic>? extraData;

  WeeklyInsightSlide({
    required this.index,
    required this.type,
    required this.badge,
    required this.headline,
    required this.subheadline,
    this.primaryMetric,
    this.metricLabel,
    this.changeTag,
    this.footerNote,
    this.chartData,
    this.extraData,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'type': type.name,
        'badge': badge,
        'headline': headline,
        'subheadline': subheadline,
        'primary_metric': primaryMetric,
        'metric_label': metricLabel,
        'change_tag': changeTag,
        'footer_note': footerNote,
        'chart_data': chartData,
        'extra_data': extraData,
      };

  factory WeeklyInsightSlide.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? 'flashSummary';
    final slideType = StorySlideType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => StorySlideType.flashSummary,
    );

    return WeeklyInsightSlide(
      index: (map['index'] as num?)?.toInt() ?? 0,
      type: slideType,
      badge: map['badge'] ?? '',
      headline: map['headline'] ?? '',
      subheadline: map['subheadline'] ?? '',
      primaryMetric: map['primary_metric']?.toString(),
      metricLabel: map['metric_label']?.toString(),
      changeTag: map['change_tag']?.toString(),
      footerNote: map['footer_note']?.toString(),
      chartData: map['chart_data'] as List<dynamic>?,
      extraData: map['extra_data'] as Map<String, dynamic>?,
    );
  }
}

/// Contenedor maestro con las 5 historias semanales y metadatos de modo
class WeeklyInsightsPayload {
  final DateTime weekStart;
  final DateTime weekEnd;
  final bool isRescueMode;
  final int totalCompletionsThisWeek;
  final int totalCompletionsLastWeek;
  final double changePercentage;
  final List<DailyRhythmItem> dailyRhythm;
  final List<MacroGrowthItem> macroGrowth;
  final MvpHighlight? mvp;
  final AnchorMicroWin? anchorMicroWin;
  final List<WeeklyInsightSlide> slides;
  final DateTime generatedAt;

  WeeklyInsightsPayload({
    required this.weekStart,
    required this.weekEnd,
    required this.isRescueMode,
    required this.totalCompletionsThisWeek,
    required this.totalCompletionsLastWeek,
    required this.changePercentage,
    required this.dailyRhythm,
    required this.macroGrowth,
    this.mvp,
    this.anchorMicroWin,
    required this.slides,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
        'week_start': weekStart.toIso8601String(),
        'week_end': weekEnd.toIso8601String(),
        'is_rescue_mode': isRescueMode,
        'total_this_week': totalCompletionsThisWeek,
        'total_last_week': totalCompletionsLastWeek,
        'change_pct': changePercentage,
        'daily_rhythm': dailyRhythm.map((d) => d.toMap()).toList(),
        'macro_growth': macroGrowth.map((m) => m.toMap()).toList(),
        'mvp': mvp?.toMap(),
        'anchor_micro_win': anchorMicroWin?.toMap(),
        'slides': slides.map((s) => s.toMap()).toList(),
        'generated_at': generatedAt.toIso8601String(),
      };

  factory WeeklyInsightsPayload.fromMap(Map<String, dynamic> map) {
    return WeeklyInsightsPayload(
      weekStart: DateTime.tryParse(map['week_start'] ?? '') ?? DateTime.now(),
      weekEnd: DateTime.tryParse(map['week_end'] ?? '') ?? DateTime.now(),
      isRescueMode: map['is_rescue_mode'] == true,
      totalCompletionsThisWeek: (map['total_this_week'] as num?)?.toInt() ?? 0,
      totalCompletionsLastWeek: (map['total_last_week'] as num?)?.toInt() ?? 0,
      changePercentage: (map['change_pct'] as num?)?.toDouble() ?? 0.0,
      dailyRhythm: (map['daily_rhythm'] as List<dynamic>?)
              ?.map((e) => DailyRhythmItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      macroGrowth: (map['macro_growth'] as List<dynamic>?)
              ?.map((e) => MacroGrowthItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      mvp: map['mvp'] != null ? MvpHighlight.fromMap(map['mvp'] as Map<String, dynamic>) : null,
      anchorMicroWin: map['anchor_micro_win'] != null
          ? AnchorMicroWin.fromMap(map['anchor_micro_win'] as Map<String, dynamic>)
          : null,
      slides: (map['slides'] as List<dynamic>?)
              ?.map((e) => WeeklyInsightSlide.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      generatedAt: DateTime.tryParse(map['generated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
