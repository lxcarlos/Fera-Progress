import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum AppVisualStyle {
  staticColor,
  tron,
  pulse,
  wave,
  rainbow,
  monochrome,
}

extension AppVisualStyleExtension on AppVisualStyle {
  String get displayName {
    switch (this) {
      case AppVisualStyle.staticColor:
        return 'Estático';
      case AppVisualStyle.tron:
        return 'Tron Neón';
      case AppVisualStyle.pulse:
        return 'Latido';
      case AppVisualStyle.wave:
        return 'Onda';
      case AppVisualStyle.rainbow:
        return 'Rainbow RGB';
      case AppVisualStyle.monochrome:
        return 'Sin color';
    }
  }

  String get description {
    switch (this) {
      case AppVisualStyle.staticColor:
        return 'Color sólido fijo sin movimiento';
      case AppVisualStyle.tron:
        return 'Respiración luminosa tenue estilo neón';
      case AppVisualStyle.pulse:
        return 'Doble pulsación rítmica sutil';
      case AppVisualStyle.wave:
        return 'Ondulación suave de luminosidad';
      case AppVisualStyle.rainbow:
        return 'Ciclo continuo de colores cromáticos';
      case AppVisualStyle.monochrome:
        return 'Modo minimalista en escala de grises';
    }
  }

  bool get isAnimated {
    return this == AppVisualStyle.tron ||
        this == AppVisualStyle.pulse ||
        this == AppVisualStyle.wave ||
        this == AppVisualStyle.rainbow;
  }
}

/// Controlador de alta eficiencia para animación de acentos visuales.
/// Utiliza el [Ticker] del sistema de Flutter para sincronizarse exactamente
/// con la tasa de refresco (60/120 Hz) sin provocar ningún rebuild en el árbol de widgets.
class DynamicAccentController {
  AppVisualStyle _style = AppVisualStyle.staticColor;
  Color _baseColor = const Color(0xFF4ADE80);
  bool _isDark = true;

  late final ValueNotifier<Color> colorNotifier;
  late final ValueNotifier<double> glowNotifier;

  Ticker? _ticker;

  // Cache para modo monocromático
  static const Color monoDark = Color(0xFFE4E4E7);
  static const Color monoLight = Color(0xFF27272A);

  DynamicAccentController({
    AppVisualStyle initialStyle = AppVisualStyle.staticColor,
    Color initialBaseColor = const Color(0xFF4ADE80),
    bool isDark = true,
  }) {
    _style = initialStyle;
    _baseColor = initialBaseColor;
    _isDark = isDark;

    final initialColor = _resolveColor(Duration.zero);
    colorNotifier = ValueNotifier<Color>(initialColor);
    glowNotifier = ValueNotifier<double>(_style == AppVisualStyle.tron ? 4.0 : 0.0);

    _initTicker();
  }

  AppVisualStyle get style => _style;
  Color get baseColor => _baseColor;
  Color get currentColor => colorNotifier.value;
  double get currentGlow => glowNotifier.value;

  void updateThemeBrightness(bool isDark) {
    if (_isDark != isDark) {
      _isDark = isDark;
      if (_style == AppVisualStyle.monochrome) {
        colorNotifier.value = _isDark ? monoDark : monoLight;
      }
    }
  }

  void setBaseColor(Color color) {
    _baseColor = color;
    if (_style == AppVisualStyle.monochrome) {
      _style = AppVisualStyle.staticColor;
    }
    _syncTickerState();
    _updateImmediate();
  }

  void setStyle(AppVisualStyle newStyle) {
    if (_style == newStyle) return;
    _style = newStyle;
    _syncTickerState();
    _updateImmediate();
  }

  void _initTicker() {
    _ticker = Ticker(_onTick);
    _syncTickerState();
  }

  void _syncTickerState() {
    if (_style.isAnimated) {
      if (_ticker != null && !_ticker!.isActive) {
        _ticker!.start();
      }
    } else {
      if (_ticker != null && _ticker!.isActive) {
        _ticker!.stop();
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (!_style.isAnimated) return;

    final seconds = elapsed.inMicroseconds / 1000000.0;
    final newColor = _computeAnimatedColor(seconds);
    final newGlow = _computeAnimatedGlow(seconds);

    if (colorNotifier.value != newColor) {
      colorNotifier.value = newColor;
    }
    if (glowNotifier.value != newGlow) {
      glowNotifier.value = newGlow;
    }
  }

  void _updateImmediate() {
    final newColor = _resolveColor(Duration.zero);
    colorNotifier.value = newColor;
    glowNotifier.value = _style == AppVisualStyle.tron ? 4.0 : 0.0;
  }

  Color _resolveColor(Duration elapsed) {
    if (_style == AppVisualStyle.monochrome) {
      return _isDark ? monoDark : monoLight;
    }
    if (!_style.isAnimated) {
      return _baseColor;
    }
    return _computeAnimatedColor(elapsed.inMicroseconds / 1000000.0);
  }

  Color _computeAnimatedColor(double t) {
    switch (_style) {
      case AppVisualStyle.tron:
        // Ciclo de respiración tenue de 3.6 segundos:
        // oscila suavemente entre un 70% y 100% de brillo y saturación
        final wave = (sin(t * (2 * pi / 3.6)) + 1) / 2; // [0.0 .. 1.0]
        final hsv = HSVColor.fromColor(_baseColor);
        final dynamicValue = (hsv.value * (0.72 + 0.28 * wave)).clamp(0.0, 1.0);
        final dynamicSat = (hsv.saturation * (0.80 + 0.20 * wave)).clamp(0.0, 1.0);
        return hsv.withValue(dynamicValue).withSaturation(dynamicSat).toColor();

      case AppVisualStyle.pulse:
        // Latido rítmico elegante: 2 segundos por ciclo con doble pulso sutil
        final cycle = (t % 2.0) / 2.0; // [0.0 .. 1.0]
        double p = 0.0;
        if (cycle < 0.14) {
          p = sin((cycle / 0.14) * pi);
        } else if (cycle >= 0.18 && cycle < 0.32) {
          p = sin(((cycle - 0.18) / 0.14) * pi) * 0.7;
        }
        final hsv = HSVColor.fromColor(_baseColor);
        final dynamicValue = (hsv.value * (0.78 + 0.22 * p)).clamp(0.0, 1.0);
        return hsv.withValue(dynamicValue).toColor();

      case AppVisualStyle.wave:
        // Onda armónica continua: 2.8 segundos de periodo
        final wave = (sin(t * (2 * pi / 2.8)) + 1) / 2;
        final hsv = HSVColor.fromColor(_baseColor);
        // Desplazamiento sutil de matiz (+- 8 grados) y luminosidad
        final shiftedHue = (hsv.hue + (wave - 0.5) * 16.0) % 360.0;
        final dynamicValue = (hsv.value * (0.82 + 0.18 * wave)).clamp(0.0, 1.0);
        return HSVColor.fromAHSV(
          1.0,
          shiftedHue < 0 ? shiftedHue + 360 : shiftedHue,
          hsv.saturation,
          dynamicValue,
        ).toColor();

      case AppVisualStyle.rainbow:
        // Ciclo RGB cromático continuo: vuelta completa en 10 segundos
        final hue = (t * 36.0) % 360.0;
        return HSVColor.fromAHSV(1.0, hue, 0.72, 0.95).toColor();

      case AppVisualStyle.monochrome:
        return _isDark ? monoDark : monoLight;

      case AppVisualStyle.staticColor:
        return _baseColor;
    }
  }

  double _computeAnimatedGlow(double t) {
    if (_style == AppVisualStyle.tron) {
      final wave = (sin(t * (2 * pi / 3.6)) + 1) / 2;
      return 2.0 + 6.0 * wave; // Radio de 2 a 8 px
    }
    if (_style == AppVisualStyle.pulse) {
      final cycle = (t % 2.0) / 2.0;
      double p = 0.0;
      if (cycle < 0.14) {
        p = sin((cycle / 0.14) * pi);
      } else if (cycle >= 0.18 && cycle < 0.32) {
        p = sin(((cycle - 0.18) / 0.14) * pi) * 0.7;
      }
      return 1.5 + 5.5 * p;
    }
    if (_style == AppVisualStyle.wave) {
      final wave = (sin(t * (2 * pi / 2.8)) + 1) / 2;
      return 2.0 + 4.5 * wave;
    }
    if (_style == AppVisualStyle.rainbow) {
      return 4.0;
    }
    return 0.0;
  }

  void dispose() {
    _ticker?.dispose();
    colorNotifier.dispose();
    glowNotifier.dispose();
  }
}

/// Widget ligero que escucha [DynamicAccentController.colorNotifier]
/// sin forzar la reconstrucción de ningún widget ancestro.
class DynamicAccentBuilder extends StatelessWidget {
  final DynamicAccentController controller;
  final Widget Function(BuildContext context, Color accent, double glow) builder;

  const DynamicAccentBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: controller.colorNotifier,
      builder: (context, color, _) {
        return ValueListenableBuilder<double>(
          valueListenable: controller.glowNotifier,
          builder: (context, glow, _) {
            return builder(context, color, glow);
          },
        );
      },
    );
  }
}
