import 'package:flutter/material.dart';
import '../../models/weekly_insights_data.dart';

/// 1. Story 1: El Gancho / Resumen Flash
class StoryFlashSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryFlashSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(
            text: slide.badge,
            color: payload.isRescueMode ? const Color(0xFF60A5FA) : const Color(0xFF4ADE80),
          ),
          const SizedBox(height: 16),
          Text(
            slide.headline,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 10),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8), height: 1.3),
          ),
          const SizedBox(height: 28),
          // Métrica destacada en tarjeta de vidrio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (payload.isRescueMode ? Colors.blueAccent : const Color(0xFF4ADE80)).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    payload.isRescueMode ? Icons.refresh : Icons.trending_up,
                    color: payload.isRescueMode ? Colors.blueAccent : const Color(0xFF4ADE80),
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
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      Text(
                        slide.metricLabel ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Mini mapa de calor mensual de 28 días
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Constancia últimos 28 días', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                    if (slide.changeTag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slide.changeTag!,
                          style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (col) {
                    return Column(
                      children: List.generate(7, (row) {
                        final active = !payload.isRescueMode && (col * 7 + row) % 3 != 0;
                        return Container(
                          margin: const EdgeInsets.all(2.5),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF4ADE80) : Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
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

/// 2. Story 2: El Ritmo Diario (Picos y Valles)
class StoryRhythmSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryRhythmSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(text: slide.badge, color: const Color(0xFF2DD4BF)),
          const SizedBox(height: 16),
          Text(
            slide.headline,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 10),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.75), height: 1.3),
          ),
          const SizedBox(height: 36),
          // Gráfica de barras de Lunes a Domingo
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
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          if (slide.footerNote != null)
            Text(
              slide.footerNote!,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

/// 3. Story 3: La Perspectiva Macro (Zoom Out)
class StoryMacroSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryMacroSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(text: slide.badge, color: const Color(0xFFC084FC)),
          const SizedBox(height: 16),
          Text(
            slide.headline,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 10),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.75), height: 1.3),
          ),
          const SizedBox(height: 32),
          ...payload.macroGrowth.map((m) {
            final factor = (m.completions / (payload.macroGrowth.last.completions + 1)).clamp(0.2, 1.0);
            return _MacroBarItem(
              period: m.periodLabel,
              pct: m.growthPct >= 0 ? '+${m.growthPct.toStringAsFixed(0)}%' : '${m.growthPct.toStringAsFixed(0)}%',
              factor: factor,
              completions: m.completions,
            );
          }),
        ],
      ),
    );
  }
}

/// 4. Story 4: El MVP / Highlight de la Semana
class StoryMvpSlide extends StatelessWidget {
  final WeeklyInsightSlide slide;
  final WeeklyInsightsPayload payload;

  const StoryMvpSlide({super.key, required this.slide, required this.payload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgePill(text: slide.badge, color: const Color(0xFFFACC15)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFACC15).withOpacity(0.18),
                  const Color(0xFF60A5FA).withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFACC15).withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFACC15).withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, color: Color(0xFFFACC15), size: 56),
                const SizedBox(height: 14),
                Text(
                  slide.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  slide.subheadline,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.75), height: 1.3),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatCol(title: 'Hábito / Logro', value: slide.primaryMetric ?? '1'),
                    _StatCol(title: 'Estado', value: slide.changeTag ?? 'Activo'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (slide.footerNote != null)
            Text(
              slide.footerNote!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

/// 5. Story 5: El Impulso (Cierre y Proyección)
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgePill(text: slide.badge, color: const Color(0xFF4ADE80)),
          const SizedBox(height: 16),
          Text(
            slide.headline,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 14),
          Text(
            slide.subheadline,
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8), height: 1.35),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4ADE80),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 6,
              ),
              onPressed: onCtaPressed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('¡Vamos con todo!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
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
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Sub-componentes auxiliares ----
class _BadgePill extends StatelessWidget {
  final String text;
  final Color color;
  const _BadgePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
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

  const _DayBar({
    required this.day,
    required this.value,
    required this.count,
    this.isPeak = false,
    this.isLow = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPeak
        ? const Color(0xFFFACC15)
        : (isLow ? Colors.white.withOpacity(0.2) : const Color(0xFF2DD4BF));

    return Column(
      children: [
        Text(
          count,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          width: 16,
          height: 110 * value,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isPeak
                ? [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
      ],
    );
  }
}

class _MacroBarItem extends StatelessWidget {
  final String period;
  final String pct;
  final double factor;
  final int completions;

  const _MacroBarItem({
    required this.period,
    required this.pct,
    required this.factor,
    required this.completions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(period, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
              Row(
                children: [
                  Text('$completions hab', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  const SizedBox(width: 8),
                  Text(
                    pct,
                    style: const TextStyle(color: Color(0xFFC084FC), fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              width: double.infinity,
              color: Colors.white.withOpacity(0.08),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFC084FC),
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

class _StatCol extends StatelessWidget {
  final String title;
  final String value;
  const _StatCol({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
