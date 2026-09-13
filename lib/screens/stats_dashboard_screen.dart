import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/categories.dart';
import '../models/stats_data.dart';
import '../services/stats_service.dart';
import '../theme/dynamic_accent.dart';
import '../theme/theme_provider.dart';
import '../utils/app_events.dart';
import '../utils/date_utils.dart';
import '../widgets/charts/trend_spline_chart.dart';
import '../widgets/stories/weekly_stories_viewer.dart';

class StatsDashboardScreen extends StatefulWidget {
  const StatsDashboardScreen({super.key});

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen> {
  final StatsService _statsService = StatsService();
  StatsTimeRange _selectedRange = StatsTimeRange.oneYear;
  StatsDashboardData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    AppEvents.tick.addListener(_onExternalChange);
  }

  @override
  void dispose() {
    AppEvents.tick.removeListener(_onExternalChange);
    super.dispose();
  }

  void _onExternalChange() {
    if (mounted) _loadStats(showLoading: false);
  }

  Future<void> _loadStats({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    final data = await _statsService.getDashboardStats(_selectedRange);
    if (!mounted) return;
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  void _onRangeSelected(StatsTimeRange range) {
    if (_selectedRange == range) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRange = range;
    });
    _loadStats();
  }

  void _openStories(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, _) => const WeeklyStoriesViewer(),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF090A0B), Color(0xFF131518), Color(0xFF0E1012)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F6), Color(0xFFE5EAEF)],
          );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          bottom: false,
          child: DynamicAccentBuilder(
            controller: context.read<ThemeProvider>().accentController,
            builder: (context, accent, glow) {
              return RefreshIndicator(
                onRefresh: () => _loadStats(showLoading: false),
                color: accent,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // Encabezado Superior
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Estadísticas',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: accent.withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'INSIGHTS',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Analíticas globales y consistencia de hábitos',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón de acceso a Stories Semanales
                            InkWell(
                              onTap: () => _openStories(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 20,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Selector Multitemporal en Pills
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: _buildTimeRangeSelector(accent, isDark),
                      ),
                    ),

                    // Contenido Principal
                    if (_isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_data != null) ...[
                      // 1. Grid de Tarjetas de Métricas Clave
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildMetricCardsGrid(context, _data!, accent, isDark),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // 2. Curva de Tendencia y Crecimiento (Spline)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildGlassCard(
                            context: context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.show_chart_rounded, size: 20, color: accent),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Curva de Rendimiento',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildDeltaChip(_data!.completionsChangePct),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Comparativa contra los ${_selectedRange.days} días previos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: TrendSplineChart(
                                    series: _data!.trendSeries,
                                    accentColor: accent,
                                    isDark: isDark,
                                    currentPeriodLabel: 'Período actual',
                                    previousPeriodLabel: 'Período anterior',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // 3. Consistencia de Hábitos – Heatmap año completo estilo GitHub
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildGlassCard(
                            context: context,
                            child: _buildYearHeatmapSection(context, accent, isDark),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // 4. Desglose por Categorías (siempre visible)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildGlassCard(
                            context: context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.pie_chart_outline_rounded, size: 19, color: accent),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Distribución por Categorías',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Progreso por área de vida en este período',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ..._data!.categoryBreakdown.map((catStat) {
                                  final catDef = kCategories[catStat.category] ?? kCategories['general']!;
                                  final catColor = catDef['color'] as Color;
                                  final catIcon = catDef['icon'] as IconData;
                                  final catLabel = catDef['label'] as String;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(catIcon, size: 15, color: catColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                catLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              catStat.count > 0
                                                  ? '${catStat.count}  (${catStat.percentage.toStringAsFixed(0)}%)'
                                                  : '0',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (catStat.percentage / 100).clamp(0.0, 1.0),
                                            minHeight: 6,
                                            backgroundColor: isDark
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : Colors.black.withValues(alpha: 0.06),
                                            valueColor: AlwaysStoppedAnimation<Color>(catColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 48)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Selector multitemporal estilo segmented pills
  Widget _buildTimeRangeSelector(Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: StatsTimeRange.values.map((range) {
          final isSelected = range == _selectedRange;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onRangeSelected(range),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    range.shortLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
                              ? Colors.white
                              : Colors.black87)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Grid de 4 tarjetas de métricas en Glassmorphism
  Widget _buildMetricCardsGrid(
    BuildContext context,
    StatsDashboardData data,
    Color accent,
    bool isDark,
  ) {

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                context: context,
                icon: Icons.check_circle_rounded,
                iconColor: accent,
                title: 'Completados',
                value: '${data.totalCompleted}',
                deltaPct: data.completionsChangePct,
                subtitle: 'vs período anterior',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                context: context,
                icon: Icons.percent_rounded,
                iconColor: const Color(0xFF38BDF8),
                title: 'Cumplimiento',
                value: '${(data.completionRate * 100).toStringAsFixed(0)}%',
                deltaPct: data.completionRateChangePct,
                subtitle: 'efectividad esperada',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                context: context,
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                title: 'Mejor Racha',
                value: '${data.bestStreak}d',
                badgeText: 'Activa: ${data.currentStreak}d',
                badgeColor: const Color(0xFFF97316),
                subtitle: 'días consecutivos',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                context: context,
                icon: Icons.task_alt_rounded,
                iconColor: const Color(0xFFA855F7),
                title: 'Tareas & Extras',
                value: '${data.tasksCompleted}',
                badgeText: data.extraActivitiesPoints > 0 ? '+${data.extraActivitiesPoints} pts' : null,
                badgeColor: const Color(0xFFA855F7),
                subtitle: '${data.extraActivitiesCount} activ. extras',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    double? deltaPct,
    String? badgeText,
    Color? badgeColor,
    required String subtitle,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.11) : Colors.black.withValues(alpha: 0.07),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: isDark ? 0.20 : 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: iconColor),
                  ),
                  if (deltaPct != null)
                    _buildDeltaChip(deltaPct)
                  else if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? iconColor).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor ?? iconColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeltaChip(double deltaPct) {
    if (deltaPct.abs() < 0.1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '= 0%',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
        ),
      );
    }
    final isPos = deltaPct > 0;
    final color = isPos ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${isPos ? '+' : ''}${deltaPct.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required BuildContext context,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            // En modo claro usamos un blanco sólido para que se vea sobre el fondo blanco
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.11)
                  : Colors.black.withValues(alpha: 0.09),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ─── Heatmap de año completo estilo GitHub con indicador de semana actual ───
  Widget _buildYearHeatmapSection(BuildContext context, Color accent, bool isDark) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final year = now.year;

    // Construir mapa de countsByDate desde consistencySeries de TODO el año
    // Primero cargamos los datos ya existentes (pueden ser de 30d, 90d, etc.)
    // Para tener el año completo hacemos un mapa directo de los datos disponibles
    final Map<String, int> countsByDate = {};
    for (final p in _data!.consistencySeries) {
      final key = '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}';
      countsByDate[key] = p.count;
    }

    // Calcular semana actual para resaltarla
    final todayWeekday = now.weekday % 7; // 0=Dom, 1=Lun…6=Sáb (estilo GitHub)
    final currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: todayWeekday));

    // Construir la cuadrícula estilo GitHub (Dom→Sáb, izq→der = Ene→Dic)
    final jan1 = DateTime(year, 1, 1);
    final gridStart = jan1.subtract(Duration(days: jan1.weekday % 7));
    final dec31 = DateTime(year, 12, 31);
    final totalDays = dec31.difference(gridStart).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    final maxCount = countsByDate.values.isEmpty ? 0 : countsByDate.values.reduce((a, b) => a > b ? a : b);

    String dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    Color colorFor(int count) {
      if (count == 0) return isDark ? const Color(0xFF1B1D20) : const Color(0xFFE8ECEF);
      if (maxCount == 0) return accent.withValues(alpha: 0.3);
      final ratio = count / maxCount;
      if (ratio <= 0.25) return accent.withValues(alpha: 0.30);
      if (ratio <= 0.50) return accent.withValues(alpha: 0.55);
      if (ratio <= 0.75) return accent.withValues(alpha: 0.80);
      return accent;
    }

    const monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 19, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Consistencia de Hábitos $year',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Heatmap del año · la semana actual está resaltada',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Etiquetas de mes
                Row(
                  children: [
                    const SizedBox(width: 20), // espacio de etiquetas de días
                    ...List.generate(totalWeeks, (week) {
                      final weekStart = gridStart.add(Duration(days: week * 7));
                      final showLabel = weekStart.day <= 7 && weekStart.year == year;
                      return SizedBox(
                        width: 13,
                        child: showLabel
                            ? Text(
                                monthNames[weekStart.month - 1],
                                style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                              )
                            : null,
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Días de la semana
                    Column(
                      children: ['D', 'L', 'M', 'X', 'J', 'V', 'S'].map((d) {
                        return SizedBox(
                          height: 13,
                          width: 14,
                          child: Text(
                            d,
                            style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 2),
                    // Columnas de semanas
                    ...List.generate(totalWeeks, (week) {
                      final weekStart = gridStart.add(Duration(days: week * 7));
                      final isCurrentWeek = isSameWeek(weekStart, currentWeekStart);
                      return Container(
                        margin: const EdgeInsets.only(right: 2),
                        // Sin decoración rígida — el efecto se aplica celda por celda
                        child: Column(
                          children: List.generate(7, (dow) {
                            final day = gridStart.add(Duration(days: week * 7 + dow));
                            if (day.year != year) {
                              return const SizedBox(width: 11, height: 13);
                            }
                            final count = countsByDate[dateKey(day)] ?? 0;
                            final isToday = isSameDate(day, now);

                            // Celda base
                            final cell = Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: colorFor(count),
                                borderRadius: BorderRadius.circular(2.5),
                                // Hoy: borde accent más grueso
                                border: isToday
                                    ? Border.all(color: accent, width: 1.5)
                                    : null,
                              ),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Tooltip(
                                message: '${day.day}/${day.month}: $count completado${count == 1 ? '' : 's'}',
                                child: isCurrentWeek && !isToday
                                    // Semana actual (no hoy): glow sutil de acento sin rectángulo
                                    ? DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accent.withValues(alpha: 0.45),
                                              blurRadius: 5,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: cell,
                                      )
                                    : cell,
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Leyenda
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Menos', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
            const SizedBox(width: 6),
            ...List.generate(5, (level) {
              final colors = [
                isDark ? const Color(0xFF1B1D20) : const Color(0xFFE8ECEF),
                accent.withValues(alpha: 0.30),
                accent.withValues(alpha: 0.55),
                accent.withValues(alpha: 0.80),
                accent,
              ];
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: colors[level],
                  borderRadius: BorderRadius.circular(2.5),
                  border: Border.all(
                    color: level == 0 ? (isDark ? Colors.white12 : Colors.black12) : Colors.transparent,
                    width: 0.8,
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
            Text('Más', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      ],
    );
  }

  bool isSameWeek(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
