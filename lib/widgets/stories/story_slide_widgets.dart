import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/weekly_insights_data.dart';

// =========================================================================
// 1. COMPONENTE BASE: TARJETA GLASSMORPHISM (VIDRIO ESMERILADO DE ALTA FIDELIDAD)
// =========================================================================

class FrostedGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? customSurface;

  const FrostedGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 26.0,
    this.borderColor,
    this.customSurface,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colores semánticos de superficie translúcida
    final surfaceColor = customSurface ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.52)
            : Colors.white.withValues(alpha: 0.65));

    final defaultBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? defaultBorderColor,
                width: 1.2,
              ),
              boxShadow: [
                // Sombra suave externa
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
                // Resplandor especular superior sutil (efecto cristal)
                BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.8),
                  blurRadius: 1,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta Glassmorphism con animación flotante / respiración suave
class FloatingFrostedGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? customSurface;

  const FloatingFrostedGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 26.0,
    this.borderColor,
    this.customSurface,
  });

  @override
  State<FloatingFrostedGlassCard> createState() => _FloatingFrostedGlassCardState();
}

class _FloatingFrostedGlassCardState extends State<FloatingFrostedGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        // Oscilación sinusoidal sutil de 3.5 píxeles
        final dy = sin(_floatController.value * pi) * 3.5;
        return Transform.translate(
          offset: Offset(0, -dy),
          child: FrostedGlassCard(
            padding: widget.padding,
            margin: widget.margin,
            borderRadius: widget.borderRadius,
            borderColor: widget.borderColor,
            customSurface: widget.customSurface,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// =========================================================================
// 2. STORY 1: EL GANCHO / RESUMEN FLASH
// =========================================================================

class StoryFlashSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryFlashSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.82) : const Color(0xFF334155);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    final badgeColor = payload.isRescueMode
        ? const Color(0xFF60A5FA)
        : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(text: slide.badge, color: badgeColor),
          const SizedBox(height: 14),
          Text(
            slide.headline,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 15, color: textSecondary, height: 1.3),
          ),
          const SizedBox(height: 24),
          // Tarjeta Glassmorphic flotante con la métrica flash
          FloatingFrostedGlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.20 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                  ),
                  child: Icon(
                    payload.isRescueMode ? Icons.refresh_rounded : Icons.trending_up_rounded,
                    color: badgeColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slide.primaryMetric ?? '0',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        slide.metricLabel ?? '',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Mini mapa de calor de 28 días estilo GitHub
          FrostedGlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Constancia últimos 28 días',
                      style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (slide.changeTag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          slide.changeTag!,
                          style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (col) {
                    return Column(
                      children: List.generate(7, (row) {
                        final active = !payload.isRescueMode && (col * 7 + row) % 3 != 0;
                        return Container(
                          margin: const EdgeInsets.all(3),
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: active
                                ? badgeColor
                                : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. STORY 2: EL RITMO DIARIO (PICOS Y VALLES)
// =========================================================================

class StoryRhythmSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryRhythmSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.82) : const Color(0xFF334155);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    final badgeColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(text: slide.badge, color: badgeColor),
          const SizedBox(height: 14),
          Text(
            slide.headline,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 15, color: textSecondary, height: 1.3),
          ),
          const SizedBox(height: 24),
          // Gráfica de barras de Lunes a Domingo dentro de vidrio esmerilado
          FloatingFrostedGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: payload.dailyRhythm.map((d) {
                    final maxC = payload.dailyRhythm.fold<int>(1, (m, e) => e.completions > m ? e.completions : m);
                    final factor = (d.completions / maxC).clamp(0.12, 1.0);
                    return _DayBar(
                      day: d.dayName,
                      value: factor,
                      count: '${d.completions}',
                      isPeak: d.isPeak,
                      isLow: d.isLow,
                      isDark: isDark,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (slide.footerNote != null)
            Center(
              child: Text(
                slide.footerNote!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

// =========================================================================
// 4. STORY 3: LA PERSPECTIVA MACRO (ZOOM OUT TEMPORAL)
// =========================================================================

class StoryMacroSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryMacroSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.82) : const Color(0xFF334155);

    final badgeColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(text: slide.badge, color: badgeColor),
          const SizedBox(height: 14),
          Text(
            slide.headline,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 15, color: textSecondary, height: 1.3),
          ),
          const SizedBox(height: 24),
          // Contenedor Glassmorphism con barras comparativas
          FrostedGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: payload.macroGrowth.map((m) {
                final factor = (m.completions / (payload.macroGrowth.last.completions + 1)).clamp(0.22, 1.0);
                return _MacroBarItem(
                  period: m.periodLabel,
                  pct: m.growthPct >= 0 ? '+${m.growthPct.toStringAsFixed(0)}%' : '${m.growthPct.toStringAsFixed(0)}%',
                  factor: factor,
                  completions: m.completions,
                  isDark: isDark,
                  accentColor: badgeColor,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 5. STORY 4: EL MVP / HIGHLIGHT (CORRECCIÓN DE OVERFLOW Y GLASSMORPHISM)
// =========================================================================

class StoryMvpSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryMvpSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.82) : const Color(0xFF334155);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    final badgeColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(text: slide.badge, color: badgeColor),
          const SizedBox(height: 20),

          // Tarjeta principal Glassmorphic flotante con la copa y los datos adaptativos
          FloatingFrostedGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            borderColor: badgeColor.withValues(alpha: isDark ? 0.35 : 0.25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Halo suave con la copa dorada
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: badgeColor.withValues(alpha: isDark ? 0.40 : 0.30),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: badgeColor,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 16),

                // Título del hábito / logro (Flexible sin ancho fijo)
                Text(
                  slide.headline,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtítulo explicativo
                Text(
                  slide.subheadline,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),

                // WRAP ADAPTATIVO: Solución definitiva al error de Overflow
                // Elimina anchos fijos y permite que "6 days Pilar de la semana" fluya en múltiples líneas
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (slide.primaryMetric != null && slide.primaryMetric!.isNotEmpty)
                      _FrostedMetricBadge(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: const Color(0xFFFB923C),
                        label: 'Racha / Frecuencia',
                        value: slide.primaryMetric!,
                        isDark: isDark,
                      ),
                    if (slide.changeTag != null && slide.changeTag!.isNotEmpty)
                      _FrostedMetricBadge(
                        icon: Icons.workspace_premium_rounded,
                        iconColor: badgeColor,
                        label: 'Distinción',
                        value: slide.changeTag!,
                        isDark: isDark,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          if (slide.footerNote != null)
            Text(
              slide.footerNote!,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

// =========================================================================
// 6. STORY 5: EL IMPULSO (CIERRE Y PROYECCIÓN)
// =========================================================================

class StoryImpulseSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;
  final VoidCallback onCtaPressed;

  const StoryImpulseSlide({
    super.key,
    required this.slide,
    required this.payload,
    required this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.82) : const Color(0xFF334155);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    final badgeColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgePill(text: slide.badge, color: badgeColor),
          const SizedBox(height: 16),
          Text(
            slide.headline,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 15, color: textSecondary, height: 1.35),
          ),
          const SizedBox(height: 32),
          // Botón principal de llamada a la acción con estilo neón / vidrio
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: badgeColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              onPressed: onCtaPressed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('¡Vamos con todo!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (slide.footerNote != null)
            Center(
              child: Text(
                slide.footerNote!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

// =========================================================================
// 7. SUB-COMPONENTES AUXILIARES ADAPTATIVOS
// =========================================================================

class _BadgePill extends StatelessWidget {
  final String text;
  final Color color;
  const _BadgePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.40), width: 1.2),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      ),
    );
  }
}

/// Badge métrico que soluciona el desbordamiento de texto con Wrap y Flexible
class _FrostedMetricBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;

  const _FrostedMetricBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    return Container(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final String day;
  final double value;
  final String count;
  final bool isPeak;
  final bool isLow;
  final bool isDark;

  const _DayBar({
    required this.day,
    required this.value,
    required this.count,
    this.isPeak = false,
    this.isLow = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    final color = isPeak
        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
        : (isLow
            ? (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.15))
            : (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488)));

    return Column(
      children: [
        Text(
          count,
          style: TextStyle(color: isPeak ? color : textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          width: 16,
          height: 100 * value,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isPeak
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MacroBarItem extends StatelessWidget {
  final String period;
  final String pct;
  final double factor;
  final int completions;
  final bool isDark;
  final Color accentColor;

  const _MacroBarItem({
    required this.period,
    required this.pct,
    required this.factor,
    required this.completions,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(period, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Text('$completions hab', style: TextStyle(color: textMuted, fontSize: 11)),
                  const SizedBox(width: 8),
                  Text(
                    pct,
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              width: double.infinity,
              color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
