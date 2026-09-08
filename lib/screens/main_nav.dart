import 'package:flutter/material.dart';
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
        controller: context.watch<ThemeProvider>().accentController,
        builder: (context, accent, glow) {
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onSelect,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: accent.withOpacity(0.22),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.checklist), label: 'Hábitos'),
              NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendario'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          );
        },
      ),
    );
  }
}