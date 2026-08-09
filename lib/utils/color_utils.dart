import 'package:flutter/material.dart';

/// Ajusta un color para que se vea bien según el modo, sin cambiar la
/// paleta en sí — solo cómo se pinta.
///
/// En modo claro: lo oscurece un poco y le sube la saturación, para que
/// tenga cuerpo sobre fondo blanco.
///
/// En modo oscuro: le sube la saturación (para que se vea vívido, no
/// lavado) y mantiene la luminosidad dentro de una banda que se ve bien
/// sobre fondo negro — ni tan oscuro que se pierda, ni tan claro que se
/// vea pastel/pálido. Antes solo se aclaraba sin tocar saturación, y eso
/// era justo lo que hacía que en modo oscuro los colores se vieran
/// deslavados.
Color contrastColor(Color color, bool isDark) {
  final hsl = HSLColor.fromColor(color);
  if (isDark) {
    final saturation = (hsl.saturation + 0.18).clamp(0.0, 1.0);
    final lightness = hsl.lightness.clamp(0.55, 0.72);
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  } else {
    final lightness = (hsl.lightness - 0.20).clamp(0.0, 1.0);
    final saturation = (hsl.saturation + 0.08).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }
}