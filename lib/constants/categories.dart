import 'package:flutter/material.dart';
import '../utils/color_utils.dart';
import 'color_palette.dart';

const Map<String, Map<String, dynamic>> kCategories = {
  'general': {'label': 'General', 'icon': Icons.circle, 'color': Color(0xFF4ADE80)},
  'salud': {'label': 'Salud', 'icon': Icons.favorite, 'color': Color(0xFFF87171)},
  'emocional': {'label': 'Bienestar emocional', 'icon': Icons.self_improvement, 'color': Color(0xFF60A5FA)},
  'inteligencia': {'label': 'Inteligencia', 'icon': Icons.psychology, 'color': Color(0xFFFACC15)},
  'espiritual': {'label': 'Espiritual', 'icon': Icons.auto_awesome, 'color': Color(0xFFC084FC)},
  'familiar': {'label': 'Familiar', 'icon': Icons.family_restroom, 'color': Color(0xFFFB923C)},
  'social': {'label': 'Social', 'icon': Icons.groups, 'color': Color(0xFF2DD4BF)},
  'financiera': {'label': 'Financiera', 'icon': Icons.attach_money, 'color': Color(0xFF34D399)},
};

/// Color de categoría ajustado para que se lea bien en texto/íconos pequeños.
Color categoryAccent(BuildContext context, String categoryKey) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final base = (kCategories[categoryKey] ?? kCategories['general']!)['color'] as Color;
  return contrastColor(base, isDark);
}

/// Color final a usar para pintar un hábito/tarea/evento/actividad extra:
/// si el usuario eligió un color propio (desde el selector estilo Google
/// Calendar) se usa ese; si no, se cae al color de su categoría, como antes.
Color resolveColor(BuildContext context, {String? color, required String category}) {
  if (color != null && color.isNotEmpty) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return contrastColor(hexToColor(color), isDark);
  }
  return categoryAccent(context, category);
}