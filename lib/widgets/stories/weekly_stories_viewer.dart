import 'package:flutter/material.dart';
import '../../models/weekly_insights_data.dart';
import '../../services/weekly_insights_service.dart';
import 'story_slide_widgets.dart';

// =========================================================================
// CLASIFICACIÓN Y COLORES SEMÁNTICOS PARA FONDOS DINÁMICOS
// =========================================================================

enum WeeklyPerformanceLevel {
  excellent,
  regular,
  critical,
}

WeeklyPerformanceLevel _evaluatePerformance(WeeklyInsightsPayload payload) {
  if (payload.isRescueMode) {
    return WeeklyPerformanceLevel.critical;
  }
  if (payload.totalCompletionsThisWeek >= 14 || payload.changePercentage >= 15.0) {
    return WeeklyPerformanceLevel.excellent;
  }
  return WeeklyPerformanceLevel.regular;
}

class _SemanticPalette {
  final Color auraPrimary;
  final Color auraSecondary;
  final Color bgBase;
  final Color accentColor;
  final String statusLabel;
  final IconData statusIcon;

  const _SemanticPalette({
    required this.auraPrimary,
    required this.auraSecondary,
    required this.bgBase,
    required this.accentColor,
    required this.statusLabel,
    required this.statusIcon,
  });

  factory _SemanticPalette.forLevel(WeeklyPerformanceLevel level, bool isDark) {
    if (isDark) {
      switch (level) {
        case WeeklyPerformanceLevel.excellent:
          return const _SemanticPalette(
            auraPrimary: Color(0x3534D399), // Verde Menta suave
            auraSecondary: Color(0x1510B981),
            bgBase: Color(0xFF090C0A),
            accentColor: Color(0xFF34D399),
            statusLabel: 'INSIGHTS SEMANALES',
            statusIcon: Icons.auto_awesome,
          );
        case WeeklyPerformanceLevel.regular:
          return const _SemanticPalette(
            auraPrimary: Color(0x30F59E0B), // Ámbar cálido suave
            auraSecondary: Color(0x14D97706),
            bgBase: Color(0xFF0D0B08),
            accentColor: Color(0xFFFBBF24),
            statusLabel: 'INSIGHTS SEMANALES',
            statusIcon: Icons.bolt,
          );
        case WeeklyPerformanceLevel.critical:
          return const _SemanticPalette(
            auraPrimary: Color(0x33EF4444), // Rojo desaturado suave
            auraSecondary: Color(0x14B91C1C),
            bgBase: Color(0xFF0E0808),
            accentColor: Color(0xFFF87171),
            statusLabel: 'REINICIO SEMANAL',
            statusIcon: Icons.favorite_rounded,
          );
      }
    } else {
      // Modo Claro
      switch (level) {
        case WeeklyPerformanceLevel.excellent:
          return const _SemanticPalette(
            auraPrimary: Color(0x2834D399), // Menta translúcido
            auraSecondary: Color(0x12A7F3D0),
            bgBase: Color(0xFFF4FAF6),
            accentColor: Color(0xFF059669),
            statusLabel: 'INSIGHTS SEMANALES',
            statusIcon: Icons.auto_awesome,
          );
        case WeeklyPerformanceLevel.regular:
          return const _SemanticPalette(
            auraPrimary: Color(0x22F59E0B), // Ámbar translúcido
            auraSecondary: Color(0x12FDE68A),
            bgBase: Color(0xFFFAF8F2),
            accentColor: Color(0xFFD97706),
            statusLabel: 'INSIGHTS SEMANALES',
            statusIcon: Icons.bolt,
          );
        case WeeklyPerformanceLevel.critical:
          return const _SemanticPalette(
            auraPrimary: Color(0x22EF4444), // Rojo desaturado translúcido
            auraSecondary: Color(0x10FECACA),
            bgBase: Color(0xFFFAF5F5),
            accentColor: Color(0xFFDC2626),
            statusLabel: 'REINICIO SEMANAL',
            statusIcon: Icons.favorite_rounded,
          );
      }
    }
  }
}

// =========================================================================
// WIDGET PRINCIPAL: VISOR DE HISTORIAS GLASSMORPHISM
// =========================================================================

class WeeklyStoriesViewer extends StatefulWidget {
  final WeeklyInsightsPayload? initialPayload;

  const WeeklyStoriesViewer({super.key, this.initialPayload});

  @override
  State<WeeklyStoriesViewer> createState() => _WeeklyStoriesViewerState();
}

class _WeeklyStoriesViewerState extends State<WeeklyStoriesViewer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  static const int _totalStories = 5;
  static const Duration _storyDuration = Duration(seconds: 6);

  late AnimationController _progressController;
  WeeklyInsightsPayload? _payload;
  bool _isLoading = true;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });

    if (widget.initialPayload != null) {
      _payload = widget.initialPayload;
      _isLoading = false;
      _progressController.forward();
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final payload = await WeeklyInsightsService().getWeeklyInsights();
    if (mounted) {
      setState(() {
        _payload = payload;
        _isLoading = false;
      });
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < _totalStories - 1) {
      setState(() => _currentIndex++);
      _progressController.reset();
      _progressController.forward();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressController.reset();
      _progressController.forward();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pause() {
    if (!_isPaused && !_isLoading) {
      setState(() => _isPaused = true);
      _progressController.stop();
    }
  }

  void _resume() {
    if (_isPaused && !_isLoading) {
      setState(() => _isPaused = false);
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading || _payload == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF090C0A) : const Color(0xFFF4FAF6),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF34D399)),
        ),
      );
    }

    // 1. Evaluación de rendimiento semántico y selección de paleta
    final level = _evaluatePerformance(_payload!);
    final palette = _SemanticPalette.forLevel(level, isDark);
    final currentSlide = _payload!.slides[_currentIndex];

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final progressActive = isDark ? Colors.white : const Color(0xFF0F172A);
    final progressInactive = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.14);

    return Scaffold(
      backgroundColor: palette.bgBase,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.pop(context); // Swipe down para cerrar
          }
        },
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width * 0.35) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // 2. FONDO DINÁMICO Y SEMÁNTICO (Verde Menta / Ámbar / Rojo Desaturado)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, -0.6),
                    radius: 1.4,
                    colors: [
                      palette.auraPrimary,
                      palette.auraSecondary,
                      palette.bgBase,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // 3. CONTENIDO DE LA HISTORIA ACTIVA CON TRANSICIÓN TIPO DIAPOSITIVA DE VIDRIO
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentIndex),
                  child: _buildSlideContent(currentSlide),
                ),
              ),
            ),

            // 4. BARRAS SUPERIORES DE PROGRESO SEGMENTADAS + CABECERA ACCESIBLE
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barras segmentadas
                    Row(
                      children: List.generate(_totalStories, (i) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: progressInactive,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: i < _currentIndex
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: progressActive,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                : (i == _currentIndex
                                    ? AnimatedBuilder(
                                        animation: _progressController,
                                        builder: (context, _) {
                                          return FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: _progressController.value,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: progressActive,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : const SizedBox.shrink()),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Cabecera superior con título y botón de cierre
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              palette.statusIcon,
                              color: palette.accentColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              palette.statusLabel,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideContent(WeeklyInsightSlide slide) {
    switch (slide.type) {
      case StorySlideType.flashSummary:
        return StoryFlashSlide(slide: slide, payload: _payload!);
      case StorySlideType.dailyRhythm:
        return StoryRhythmSlide(slide: slide, payload: _payload!);
      case StorySlideType.macroPerspective:
        return StoryMacroSlide(slide: slide, payload: _payload!);
      case StorySlideType.mvpHighlight:
        return StoryMvpSlide(slide: slide, payload: _payload!);
      case StorySlideType.weeklyImpulse:
        return StoryImpulseSlide(
          slide: slide,
          payload: _payload!,
          onCtaPressed: () => Navigator.pop(context),
        );
    }
  }
}
