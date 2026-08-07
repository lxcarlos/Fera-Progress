import 'dart:ui';
import 'package:flutter/material.dart';

class GlassDialog extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final List<Widget> actions;

  const GlassDialog({super.key, this.title, required this.content, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.09) : Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  DefaultTextStyle(
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                    child: title!,
                  ),
                if (title != null) const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: content)),
                const SizedBox(height: 8),
                // Si mandan un solo widget como "actions" (por ejemplo, una
                // Row con varios botones ya armada), lo dejamos ocupar todo
                // el ancho del diálogo en vez de meterlo en el Wrap
                // alineado a la derecha. Así los botones de "¿Eliminar
                // evento repetido?" quedan centrados y de corrido en una
                // sola línea, en vez de que el último se vaya a una
                // segunda fila.
                if (actions.length == 1)
                  SizedBox(width: double.infinity, child: actions.first)
                else
                  // Wrap en vez de Row: si los botones sueltos no caben en
                  // una sola línea, pasan a una segunda en vez de
                  // desbordar el ancho del diálogo ("RIGHT OVERFLOWED").
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: actions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int maxLines;

  const GlassField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
          border: InputBorder.none,
          counterStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
        ),
      ),
    );
  }
}