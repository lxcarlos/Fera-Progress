import 'package:flutter/material.dart';
import '../../models/weekly_insights_data.dart';
import '../../services/weekly_insights_service.dart';
import 'story_slide_widgets.dart';

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
    if (_isLoading || _payload == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
        ),
      );
    }

    final currentSlide = _payload!.slides[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.pop(context); // Deslizar abajo para cerrar
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
            // Fondo de gradiente ambiental oscuro
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.3,
                    colors: [
                      (_payload!.isRescueMode ? Colors.blueAccent : const Color(0xFF4ADE80)).withOpacity(0.16),
                      const Color(0xFF070707),
                    ],
                  ),
                ),
              ),
            ),

            // Contenido de la historia activa
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentIndex),
                  child: _buildSlideContent(currentSlide),
                ),
              ),
            ),

            // Barras superiores de progreso segmentadas + Cabecera
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: List.generate(_totalStories, (i) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: i < _currentIndex
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
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
                                                color: Colors.white,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _payload!.isRescueMode ? Icons.favorite : Icons.auto_awesome,
                              color: _payload!.isRescueMode ? Colors.blueAccent : Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _payload!.isRescueMode ? 'REINICIO SEMANAL' : 'INSIGHTS SEMANALES',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
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
