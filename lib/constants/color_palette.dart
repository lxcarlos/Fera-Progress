import 'package:flutter/material.dart';
import '../widgets/glass_dialog.dart';

/// Paleta fija de colores para elegir, al estilo del selector de colores de
/// Google Calendar. Cada uno se guarda como un string hex (ej: "#F87171").
const List<String> kColorPalette = [
  '#F87171', // rojo
  '#FB923C', // naranja
  '#FBBF24', // ámbar
  '#FACC15', // amarillo
  '#A3E635', // lima
  '#4ADE80', // verde
  '#34D399', // esmeralda
  '#2DD4BF', // turquesa
  '#22D3EE', // cian
  '#60A5FA', // azul
  '#818CF8', // índigo
  '#A78BFA', // violeta
  '#C084FC', // morado
  '#E879F9', // fucsia
  '#F472B6', // rosa
  '#FB7185', // rosa fuerte
  '#94A3B8', // gris azulado
  '#78716C', // café
];

Color hexToColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}

/// Abre la cuadrícula de colores (como la de Google Calendar) en una hoja
/// modal y devuelve el hex elegido, o null si canceló / no cambió nada.
/// Siempre quita el foco del teclado antes de abrir, para que si el
/// usuario estaba escribiendo, el teclado no se reabra solo al cerrar.
Future<String?> showColorPicker(BuildContext context, {String? selected}) {
  FocusScope.of(context).unfocus();
  return showDialog<String>(
    context: context,
    builder: (context) => GlassDialog(
      title: const Text('Elegir color'),
      content: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: kColorPalette.map((hex) {
          final isSelected = hex == selected;
          final color = hexToColor(hex);
          return GestureDetector(
            onTap: () => Navigator.pop(context, hex),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: isSelected ? 10 : 0)],
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    ),
  );
}

/// Punto/circulito de color con etiqueta, para meter dentro de los
/// diálogos de crear/editar evento, hábito, tarea o actividad extra.
/// Al tocarlo abre showColorPicker.
class ColorPickerField extends StatelessWidget {
  final String? selectedColor;
  final Color fallbackColor; // color de categoría, si no hay color propio elegido
  final ValueChanged<String?> onChanged;

  const ColorPickerField({
    super.key,
    required this.selectedColor,
    required this.fallbackColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shown = selectedColor != null ? hexToColor(selectedColor!) : fallbackColor;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final result = await showColorPicker(context, selected: selectedColor);
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: shown, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedColor == null ? 'Color (según categoría)' : 'Color personalizado',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
              ),
            ),
            if (selectedColor != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Quitar color y usar el de la categoría',
                onPressed: () => onChanged(null),
              ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}