import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/dynamic_accent.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();

  late final List<Widget> _tabs = [
    const HomeScreen(),
    CalendarScreen(key: _calendarKey),
    const ProfileScreen(),
  ];

  void _onSelect(int i) {
    setState(() => _index = i);
    if (i == 1) {
      _calendarKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: List.generate(_tabs.length, (i) {
          final active = i == _index;
          return IgnorePointer(
            ignoring: !active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _tabs[i],
            ),
          );
        }),
      ),
      bottomNavigationBar: DynamicAccentBuilder(
        controller: context.read<ThemeProvider>().accentController,
        builder: (context, accent, glow) {
          final isDark = theme.brightness == Brightness.dark;
          final isTron = context.watch<ThemeProvider>().visualStyle == AppVisualStyle.tron;
          final borderGlow = isTron || (glow > 2.0);

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C0C0E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: accent.withOpacity(borderGlow ? 0.35 : 0.12),
                  width: borderGlow ? 1.4 : 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -3),
                ),
                if (borderGlow)
                  BoxShadow(
                    color: accent.withOpacity(0.18),
                    blurRadius: glow * 1.5,
                    offset: const Offset(0, -2),
                  ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_tabs.length, (i) {
                    final active = i == _index;
                    final icons = const [
                      (Icons.checklist_rounded, Icons.checklist_outlined, 'Hábitos'),
                      (Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Calendario'),
                      (Icons.person_rounded, Icons.person_outline_rounded, 'Perfil'),
                    ];
                    final item = icons[i];

                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _onSelect(i);
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: active ? 16 : 8,
                              vertical: active ? 6 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: active ? accent.withOpacity(isDark ? 0.18 : 0.14) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: active
                                  ? Border.all(
                                      color: accent.withOpacity(borderGlow ? 0.55 : 0.35),
                                      width: 1.2,
                                    )
                                  : null,
                              boxShadow: active && borderGlow
                                  ? [
                                      BoxShadow(
                                        color: accent.withOpacity(0.25),
                                        blurRadius: glow * 1.2,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: active ? 1.14 : 1.0,
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutBack,
                                  child: Icon(
                                    active ? item.$1 : item.$2,
                                    size: 22,
                                    color: active ? accent : theme.colorScheme.onSurface.withOpacity(0.48),
                                  ),
                                ),
                                if (active) ...[
                                  const SizedBox(width: 8),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 240),
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      letterSpacing: 0.2,
                                    ),
                                    child: Text(item.$3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}