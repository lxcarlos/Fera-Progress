import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dynamic_accent.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _seedColor = const Color(0xFF4ADE80);
  AppVisualStyle _visualStyle = AppVisualStyle.staticColor;
  late final DynamicAccentController accentController;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  AppVisualStyle get visualStyle => _visualStyle;
  bool get isMonochrome => _visualStyle == AppVisualStyle.monochrome;
  bool get isRainbow => _visualStyle == AppVisualStyle.rainbow;

  static const List<Color> presetColors = [
    Color(0xFF4ADE80), // Verde esmeralda
    Color(0xFF60A5FA), // Azul cielo
    Color(0xFFC084FC), // Morado / Neón
    Color(0xFFF87171), // Rojo coral
    Color(0xFFFACC15), // Amarillo eléctrico
    Color(0xFF2DD4BF), // Turquesa / Cian Tron
    Color(0xFFFB923C), // Naranja neón
    Color(0xFFF472B6), // Rosa cyber
  ];

  ThemeProvider() {
    accentController = DynamicAccentController(
      initialStyle: _visualStyle,
      initialBaseColor: _seedColor,
      isDark: _themeMode == ThemeMode.dark,
    );
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('theme_mode') ?? 2;
    final colorValue = prefs.getInt('seed_color');
    final styleIndex = prefs.getInt('visual_style');

    _themeMode = ThemeMode.values[modeIndex];
    if (colorValue != null) _seedColor = Color(colorValue);

    if (styleIndex != null && styleIndex >= 0 && styleIndex < AppVisualStyle.values.length) {
      _visualStyle = AppVisualStyle.values[styleIndex];
    }

    accentController.setStyle(_visualStyle);
    accentController.setBaseColor(_seedColor);
    accentController.updateThemeBrightness(_themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final isDark = mode == ThemeMode.dark;
    accentController.updateThemeBrightness(isDark);
    notifyListeners();
    if (mode != ThemeMode.system) {
      SystemChrome.setSystemUIOverlayStyle(overlayStyleFor(isDark));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    // Si estaba en monocromo o rainbow, al seleccionar un color explícito activamos el estilo previo o estático
    if (_visualStyle == AppVisualStyle.monochrome || _visualStyle == AppVisualStyle.rainbow) {
      _visualStyle = AppVisualStyle.staticColor;
      accentController.setStyle(AppVisualStyle.staticColor);
    }
    accentController.setBaseColor(color);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_color', color.toARGB32());
    await prefs.setInt('visual_style', _visualStyle.index);
  }

  Future<void> setVisualStyle(AppVisualStyle style) async {
    _visualStyle = style;
    accentController.setStyle(style);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('visual_style', style.index);
  }

  Future<void> disableColor() async {
    await setVisualStyle(AppVisualStyle.monochrome);
  }

  Color get effectivePrimaryColor {
    if (_visualStyle == AppVisualStyle.monochrome) {
      return _themeMode == ThemeMode.dark
          ? DynamicAccentController.monoDark
          : DynamicAccentController.monoLight;
    }
    return _seedColor;
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
          primary: effectivePrimaryColor,
          secondary: effectivePrimaryColor,
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
          primary: effectivePrimaryColor,
          secondary: effectivePrimaryColor,
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

  @override
  void dispose() {
    accentController.dispose();
    super.dispose();
  }
}