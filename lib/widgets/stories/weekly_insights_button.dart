import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/dynamic_accent.dart';
import 'weekly_stories_viewer.dart';

class WeeklyInsightsButton extends StatefulWidget {
  final bool isCompact;

  const WeeklyInsightsButton({super.key, this.isCompact = false});

  @override
  State<WeeklyInsightsButton> createState() => _WeeklyInsightsButtonState();
}

class _WeeklyInsightsButtonState extends State<WeeklyInsightsButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openStories(BuildContext context) {
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
    final isSunday = DateTime.now().weekday == DateTime.sunday;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DynamicAccentBuilder(
      controller: context.read<ThemeProvider>().accentController,
      builder: (context, accent, glow) {
        if (widget.isCompact) {
          // Versión compacta para el AppBar
          return IconButton(
            icon: Icon(Icons.auto_awesome, color: isSunday ? accent : theme.colorScheme.onSurface.withOpacity(0.8)),
            tooltip: 'Insights Semanales',
            onPressed: () => _openStories(context),
          );
        }

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseScale = isSunday ? 1.0 + (_pulseController.value * 0.04) : 1.0;
            final glowIntensity = isSunday ? (4.0 + (_pulseController.value * 8.0)) : 2.0;

            return Transform.scale(
              scale: pulseScale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(isDark ? 0.35 : 0.18),
                      blurRadius: glowIntensity,
                      spreadRadius: isSunday ? 1 : 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _openStories(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141414) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accent.withOpacity(isSunday ? 0.85 : 0.3),
                          width: isSunday ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isSunday ? '✨ Ver Insights del Domingo' : 'Insights Semanales',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (isSunday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NUEVO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
