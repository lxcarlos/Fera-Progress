import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPickerOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  const GlassPickerOption({required this.value, required this.label, this.icon, this.color});
}

/// Selector con el mismo estilo "glass" (borroso, redondeado) del resto de
/// la app, como bottom sheet: aparece a media altura, cómodo para el pulgar
/// (ni pegado arriba ni hasta abajo del todo).
Future<T?> showGlassPicker<T>(
  BuildContext context, {
  required String title,
  required List<GlassPickerOption<T>> options,
  T? selected,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16,
          top: MediaQuery.of(context).size.height * 0.18,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.09) : Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.8), width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.5 : 0.12), blurRadius: 30, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final opt = options[i];
                        final isSelected = opt.value == selected;
                        final accent = opt.color ?? theme.colorScheme.primary;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(context, opt.value),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? accent.withOpacity(0.16) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isSelected ? accent.withOpacity(0.5) : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    if (opt.icon != null) ...[
                                      Icon(opt.icon, size: 16, color: accent),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: Text(opt.label,
                                          style: TextStyle(
                                            color: isSelected ? accent : theme.colorScheme.onSurface.withOpacity(0.85),
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 14,
                                          )),
                                    ),
                                    if (isSelected) Icon(Icons.check, size: 16, color: accent),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Igual que [showGlassPicker] pero de selección múltiple: permite escoger
/// cero, uno o varios valores (por ejemplo, vincular un evento a varios
/// hábitos/tareas a la vez). Se confirma con el botón "Listo".
Future<List<T>?> showGlassMultiPicker<T>(
  BuildContext context, {
  required String title,
  required List<GlassPickerOption<T>> options,
  required List<T> selected,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final current = List<T>.from(selected);

  return showModalBottomSheet<List<T>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16,
              top: MediaQuery.of(context).size.height * 0.18,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.09) : Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.8), width: 1.2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.5 : 0.12), blurRadius: 30, offset: const Offset(0, 12))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          itemCount: options.length,
                          itemBuilder: (context, i) {
                            final opt = options[i];
                            final isSelected = current.contains(opt.value);
                            final accent = opt.color ?? theme.colorScheme.primary;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setSheetState(() {
                                    if (isSelected) {
                                      current.remove(opt.value);
                                    } else {
                                      current.add(opt.value);
                                    }
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? accent.withOpacity(0.16) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: isSelected ? accent.withOpacity(0.5) : Colors.transparent),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                          size: 18,
                                          color: isSelected ? accent : theme.colorScheme.onSurface.withOpacity(0.35),
                                        ),
                                        const SizedBox(width: 10),
                                        if (opt.icon != null) ...[
                                          Icon(opt.icon, size: 16, color: accent),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: Text(opt.label,
                                              style: TextStyle(
                                                color: isSelected ? accent : theme.colorScheme.onSurface.withOpacity(0.85),
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                fontSize: 14,
                                              )),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context, current),
                            child: Text(current.isEmpty ? 'Listo (sin vincular)' : 'Listo (${current.length})'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Campo tipo "glass" que abre el picker de arriba al tocarlo.
/// Se usa en vez de un DropdownButtonFormField para mantener el mismo
/// diseño del resto de la app.
class GlassPickerField<T> extends StatelessWidget {
  final String label;
  final String valueLabel;
  final IconData? valueIcon;
  final Color? valueColor;
  final VoidCallback onTap;

  const GlassPickerField({
    super.key,
    required this.label,
    required this.valueLabel,
    this.valueIcon,
    this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = valueColor ?? theme.colorScheme.onSurface;


    return GestureDetector(
      onTap: () {
        // Si había un campo de texto con el teclado abierto, le quitamos
        // el foco ANTES de abrir el selector. Si no hacemos esto, al
        // cerrar el selector Flutter le devuelve el foco a ese campo y el
        // teclado se vuelve a abrir solo, sin que el usuario lo pida.
        FocusScope.of(context).unfocus();
        onTap();
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.45), fontSize: 11)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (valueIcon != null) ...[Icon(valueIcon, size: 14, color: accent), const SizedBox(width: 6)],
                      Flexible(
                        child: Text(valueLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.unfold_more, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }
}