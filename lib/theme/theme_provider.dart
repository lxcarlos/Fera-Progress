import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // Lo aplicamos también de forma directa (no solo vía AnnotatedRegion),
    // como refuerzo para que el cambio de color de las barras del sistema
    // se note al toque en teléfonos donde el widget tree tarda en
    // repintarse o donde el sistema es más terco (varios Samsung).
    final isDark = mode == ThemeMode.dark;
    if (mode != ThemeMode.system) {
      SystemChrome.setSystemUIOverlayStyle(overlayStyleFor(isDark));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }


  
  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_color', color.value);
  }

  // Fondo transparente + estilo de iconos EXPLÍCITO. Ojo: Colors.transparent
  // por sí solo hace que Flutter calcule mal el brillo del AppBar (lo lee
  // como "negro" porque ignora el canal alfa) y siempre ponga iconos
  // blancos en la barra de estado, aunque estés en modo claro. Por eso acá
  // se le dice a mano cuál usar según el tema.
  static const _darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  static const _lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF7F9F7),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: ColorScheme.dark(
          primary: _seedColor,
          secondary: _seedColor,
          surface: const Color(0xFF0C0C0C),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: _darkOverlay,
        ),
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
          systemOverlayStyle: _lightOverlay,
        ),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData(brightness: Brightness.light).textTheme),
      );

  /// Estilo a usar en pantallas SIN AppBar (donde no hay quien le diga al
  /// sistema qué iconos poner), por ejemplo detrás de MaterialApp.builder.
  SystemUiOverlayStyle overlayStyleFor(bool isDark) => isDark ? _darkOverlay : _lightOverlay;

  List<Color> gradientColors(bool isDark) {
    return isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];
  }
}