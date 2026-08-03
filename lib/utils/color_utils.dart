import 'package:flutter/material.dart';

/// Ajusta un color para que tenga buen contraste según el modo.
/// En modo claro lo oscurece, en modo oscuro lo aclara un poco.
Color contrastColor(Color color, bool isDark) {
  final hsl = HSLColor.fromColor(color);
  if (isDark) {
    final lightness = (hsl.lightness + 0.12).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  } else {
    final lightness = (hsl.lightness - 0.20).clamp(0.0, 1.0); 
    final saturation = (hsl.saturation + 0.08).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }
}