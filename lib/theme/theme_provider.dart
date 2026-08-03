import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _seedColor = const Color(0xFF4ADE80);

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  static const List<Color> presetColors = [
    Color(0xFF4ADE80),
    Color(0xFF60A5FA),
    Color(0xFFC084FC),
    Color(0xFFF87171),
    Color(0xFFFACC15),
    Color(0xFF2DD4BF),
    Color(0xFFFB923C),
    Color(0xFFF472B6),
  ];

  ThemeProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('theme_mode') ?? 2;
    final colorValue = prefs.getInt('seed_color');
    _themeMode = ThemeMode.values[modeIndex];
    if (colorValue != null) _seedColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_color', color.value);
  }

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: ColorScheme.dark(
          primary: _seedColor,
          secondary: _seedColor,
          surface: const Color(0xFF0C0C0C),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
      );

  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F9F7),
        colorScheme: ColorScheme.light(
          primary: _seedColor,
          secondary: _seedColor,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black87),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData(brightness: Brightness.light).textTheme),
      );

  List<Color> gradientColors(bool isDark) {
    return isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];
  }
}