import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../models/habit.dart';

import '../constants/categories.dart';
import '../constants/color_palette.dart';

import 'glass_dialog.dart';
import 'glass_picker.dart';


// Orden L M X J V S D, con el valor real de DateTime.weekday (1=lunes..7=domingo).
const List<Map<String, dynamic>> _kWeekdayOptions = [
  {'value': 1, 'label': 'L'},
  {'value': 2, 'label': 'M'},
  {'value': 3, 'label': 'X'},
  {'value': 4, 'label': 'J'},
  {'value': 5, 'label': 'V'},
  {'value': 6, 'label': 'S'},
  {'value': 7, 'label': 'D'},
];

/// Fila de bolitas L M X J V S D para elegir en qué días de la semana se
/// repite el evento. Selección múltiple: se puede tocar más de una.
class _WeekdaySelector extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  final Color accent;

  const _WeekdaySelector({required this.selected, required this.onChanged, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _kWeekdayOptions.map((opt) {
        final value = opt['value'] as int;
        final isSelected = selected.contains(value);
        return GestureDetector(
          onTap: () {
            final next = List<int>.from(selected);
            if (isSelected) {
              next.remove(value);
            } else {
              next.add(value);
            }
            onChanged(next);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? accent : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
              border: Border.all(color: isSelected ? accent : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1))),
            ),
            child: Text(
              opt['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Pregunta cómo eliminar un evento repetido: solo esta ocurrencia, o esta
/// y todas las siguientes (las anteriores a la fecha actual no se tocan).
/// Devuelve 'one', 'forward' o null (canceló).



Future<String?> _askDeleteScope(BuildContext context, {required bool isRecurring}) {
  if (!isRecurring) {
    return showDialog<String>(
      context: context,
      builder: (context) => GlassDialog(
        title: const Text('¿Eliminar evento?'),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, 'one'),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  return showDialog<String>(
    context: context,
    builder: (context) => GlassDialog(
      title: const Text('¿Eliminar evento repetido?'),
      content: const Text(
        'Este evento se repite. Elige qué quieres eliminar. Esta acción no se puede deshacer.',
        style: TextStyle(fontSize: 13),
      ),
      // Un solo widget en "actions": GlassDialog lo estira a todo el
      // ancho y así los 3 botones quedan centrados, de corrido, en una
      // sola línea.
      actions: [_scopeButtonsRow(context, deleteMode: true)],
    ),
  );
}

/// Pregunta cómo aplicar los cambios de un evento repetido: solo esta
/// ocurrencia, o esta y todas las siguientes. Devuelve 'one', 'forward' o
/// null (canceló, y en ese caso NO se guarda nada).
Future<String?> _askEditScope(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => GlassDialog(
      title: const Text('¿Cómo guardar los cambios?'),
      content: const Text(
        'Este evento se repite. Elige si el cambio aplica solo a este día o a este y todos los que siguen.',
        style: TextStyle(fontSize: 13),
      ),
      actions: [_scopeButtonsRow(context, deleteMode: false)],
    ),
  );
}

/// Fila de "Cancelar" / "Solo este" / "Este y siguientes" para los diálogos
/// de eliminar o editar un evento repetido. Va centrada y de corrido en una
/// sola línea: cada botón usa el mismo ancho (Expanded) y el texto se
/// achica solo (FittedBox) si el celular es angosto, en vez de desbordar
/// o saltar a una segunda fila.
Widget _scopeButtonsRow(BuildContext context, {required bool deleteMode}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Expanded(
        child: TextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12)),
          onPressed: () => Navigator.pop(context),
          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Cancelar')),
        ),
      ),
      Expanded(
        child: TextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12)),
          onPressed: () => Navigator.pop(context, 'one'),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Solo este', style: TextStyle(color: deleteMode ? Colors.red : null)),
          ),
        ),
      ),
      Expanded(
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: deleteMode ? Colors.red : null,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          ),
          onPressed: () => Navigator.pop(context, 'forward'),
          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Este y siguientes')),
        ),
      ),
    ],
  );
}




/// Suma minutos a una hora "HH:mm" (usado para calcular una hora de fin
/// por defecto cuando el usuario no eligió una).
String _addMinutes(String hhmm, int minutes) {
  final parts = hhmm.split(':');
  final total = int.parse(parts[0]) * 60 + int.parse(parts[1]) + minutes;
  final h = (total ~/ 60) % 24;
  final m = total % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Si ya hay 3 o más eventos encimados en ese horario, avisa que no es
/// posible mostrar un cuarto y sugiere agregar la actividad en la
/// descripción de uno de los eventos existentes. Devuelve true si se
/// puede continuar guardando (menos de 3 eventos en el mismo horario).
Future<bool> _confirmOverlapIfNeeded(
  BuildContext context,
  DBHelper dbHelper,
  DateTime date,
  String startTime,
  String endTime, {
  int? excludeEventId,
}) async {
  final overlapping = await dbHelper.countOverlappingEvents(date, startTime, endTime, excludeEventId: excludeEventId);
  if (overlapping < 3) return true;
  if (!context.mounted) return false;
  await showDialog(
    context: context,
    builder: (context) => GlassDialog(
      title: const Text('Demasiados eventos a la misma hora'),
      content: const Text(
        'Ya hay 3 eventos en este horario y no se pueden mostrar más al mismo tiempo en el calendario. '
        'Agrega esta actividad dentro de la descripción de uno de los eventos existentes, en vez de crear uno nuevo.',
        style: TextStyle(fontSize: 13),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
      ],
    ),
  );
  return false;
}

/// Abre el formulario de creación/edición de un evento de calendario.
/// Compartido entre la vista de Día y la vista de Semana para no duplicar código.
Future<void> showEventDialog(
  BuildContext context, {
  required DBHelper dbHelper,
  required DateTime date,
  CalendarEvent? existing,
  TimeOfDay? presetTime,
  required VoidCallback onSaved,
}) async {
  final habits = await dbHelper.getAllHabits();
  if (!context.mounted) return;

  final titleController = TextEditingController(text: existing?.title ?? '');
  final descController = TextEditingController(text: existing?.description ?? '');
  TimeOfDay startTime = existing != null
      ? TimeOfDay(hour: int.parse(existing.startTime.split(':')[0]), minute: int.parse(existing.startTime.split(':')[1]))
      : (presetTime ?? TimeOfDay.now());
  TimeOfDay? endTime = existing?.endTime != null
      ? TimeOfDay(hour: int.parse(existing!.endTime!.split(':')[0]), minute: int.parse(existing.endTime!.split(':')[1]))
      : null;
  String category = existing?.category ?? 'general';
  String recurrence = existing?.recurrence ?? 'none';
  List<int> weekdays = List<int>.from(existing?.weekdays ?? const []);
  DateTime? repeatUntil = existing?.repeatUntil;
  List<int> linkedHabitIds = List<int>.from(existing?.linkedHabitIds ?? const []);

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final linkedHabits = habits.where((h) => linkedHabitIds.contains(h.id)).toList();
        final linkAccent = Theme.of(context).colorScheme.primary;

        String linkLabel;
        if (linkedHabits.isEmpty) {
          linkLabel = 'Sin vincular';
        } else if (linkedHabits.length == 1) {
          linkLabel = linkedHabits.first.name;
        } else {
          linkLabel = '${linkedHabits.length} vinculados';
        }

        String? eventColor;
        return GlassDialog(
          title: Text(existing == null ? 'Nuevo evento' : 'Editar evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassField(controller: titleController, hint: 'Ej: Tomar el bus a la escuela'),
              const SizedBox(height: 10),
              GlassField(controller: descController, hint: 'Descripción (opcional)', maxLength: 100, maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Inicio: ${startTime.format(context)}')),
                  
                  
                  TextButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      final t = await showTimePicker(context: context, initialTime: startTime);
                      if (t != null) setDialogState(() => startTime = t);
                    },
                    child: const Text('Elegir'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text(endTime == null ? 'Sin hora de fin' : 'Fin: ${endTime!.format(context)}')),
                  TextButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      final t = await showTimePicker(context: context, initialTime: endTime ?? startTime);
                      if (t != null) setDialogState(() => endTime = t);
                    },
                    child: const Text('Elegir'),
                  ),



                  if (endTime != null)
                    IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setDialogState(() => endTime = null)),
                ],
              ),
              const SizedBox(height: 10),
              GlassPickerField<int?>(
                label: 'Vincular a hábito(s)/tarea(s)',
                valueLabel: linkLabel,
                valueIcon: linkedHabits.isNotEmpty ? Icons.link : Icons.link_off,
                valueColor: linkedHabits.isNotEmpty ? linkAccent : null,
                onTap: () async {
                  final result = await showGlassMultiPicker<int>(
                    context,
                    title: 'Vincular a hábito(s)/tarea(s)',
                    selected: linkedHabitIds,
                    options: habits.map((h) => GlassPickerOption<int>(value: h.id!, label: h.name, icon: Icons.link)).toList(),
                  );
                  if (result != null) setDialogState(() => linkedHabitIds = result);
                },
              ),
              if (linkedHabitIds.isEmpty) ...[
                const SizedBox(height: 10),
                
                










                
                GlassPickerField<String>(
                  label: 'Categoría',
                  valueLabel: (kCategories[category] ?? kCategories['general']!)['label'] as String,
                  valueIcon: (kCategories[category] ?? kCategories['general']!)['icon'] as IconData,
                  valueColor: categoryAccent(context, category),
                  onTap: () async {
                    final result = await showGlassPicker<String>(
                      context,
                      title: 'Categoría',
                      selected: category,
                      options: kCategories.entries
                          .map((e) => GlassPickerOption<String>(
                                value: e.key,
                                label: e.value['label'] as String,
                                icon: e.value['icon'] as IconData,
                                color: categoryAccent(context, e.key),
                              ))
                          .toList(),
                    );
                    if (result != null) setDialogState(() => category = result);
                  },
                ),
                const SizedBox(height: 10),
                ColorPickerField(
                  selectedColor: eventColor,
                  fallbackColor: categoryAccent(context, category),
                  onChanged: (c) => setDialogState(() => eventColor = c),
                ),




              ],
              const SizedBox(height: 10),
              GlassPickerField<String>(
                label: 'Repetir',
                valueLabel: recurrence == 'weekly' ? '1 vez cada semana' : 'No repetir',
                valueIcon: Icons.repeat,
                onTap: () async {
                  final result = await showGlassPicker<String>(
                    context,
                    title: 'Repetir',
                    selected: recurrence,
                    options: const [
                      GlassPickerOption<String>(value: 'none', label: 'No repetir', icon: Icons.event),
                      GlassPickerOption<String>(value: 'weekly', label: '1 vez cada semana', icon: Icons.repeat),
                    ],
                  );
                  if (result != null) {
                    setDialogState(() {
                      recurrence = result;
                      if (recurrence == 'none') {
                        weekdays = [];
                        repeatUntil = null;
                      } else if (recurrence == 'weekly' && weekdays.isEmpty) {
                        // Por defecto, marca el día de la fecha del evento.
                        weekdays = [date.weekday];
                      }
                    });
                  }
                },
              ),
              if (recurrence == 'weekly') ...[
                const SizedBox(height: 12),
                Text('¿Qué días?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                const SizedBox(height: 8),
                _WeekdaySelector(
                  selected: weekdays,
                  accent: Theme.of(context).colorScheme.primary,
                  onChanged: (v) => setDialogState(() => weekdays = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        repeatUntil == null
                            ? 'Repetir hasta: sin fecha límite'
                            : 'Repetir hasta: ${repeatUntil!.day}/${repeatUntil!.month}/${repeatUntil!.year}',
                      ),
                    ),
                    
                    





                    

                    TextButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: repeatUntil ?? date.add(const Duration(days: 30)),
                          firstDate: date,
                          lastDate: date.add(const Duration(days: 3650)),
                        );
                        if (picked != null) setDialogState(() => repeatUntil = picked);
                      },
                      child: const Text('Elegir'),
                    ),










                    if (repeatUntil != null)
                      IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setDialogState(() => repeatUntil = null)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  final scope = await _askDeleteScope(context, isRecurring: existing.isRecurring);
                  if (scope == null) return;
                  if (scope == 'one') {
                    await dbHelper.deleteEventOccurrence(existing, date);
                  } else if (scope == 'forward') {
                    await dbHelper.deleteEventFromDateOnward(existing, date);
                  }
                  if (context.mounted) Navigator.pop(context);
                  onSaved();
                },
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                final endStr = endTime != null ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}' : null;
                final effectiveEndForOverlap = endStr ?? _addMinutes(startStr, 30);

                final canProceed = await _confirmOverlapIfNeeded(
                  context,
                  dbHelper,
                  date,
                  startStr,
                  effectiveEndForOverlap,
                  excludeEventId: existing?.id,
                );
                if (!canProceed || !context.mounted) return;

                String finalCategory = category;
                if (linkedHabitIds.isNotEmpty) {
                  final match = habits.where((h) => h.id == linkedHabitIds.first);
                  if (match.isNotEmpty) finalCategory = match.first.category;
                }

                final effectiveRecurrence = (recurrence == 'weekly' && weekdays.isNotEmpty) ? 'weekly' : 'none';

                if (existing == null) {
                  final event = CalendarEvent(
                    title: titleController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                    startTime: startStr,
                    endTime: endStr,
                    date: date,
                    recurrence: effectiveRecurrence,
                    weekdays: effectiveRecurrence == 'weekly' ? weekdays : const [],
                    repeatUntil: effectiveRecurrence == 'weekly' ? repeatUntil : null,
                    category: finalCategory,
                    color: eventColor,
                    
                    createdAt: DateTime.now(),
                  );
                  await dbHelper.createEvent(event, linkedHabitIds: linkedHabitIds);
                } else {
                  final updated = existing.copyWith(
                    title: titleController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                    startTime: startStr,
                    endTime: endStr,
                    recurrence: effectiveRecurrence,
                    weekdays: effectiveRecurrence == 'weekly' ? weekdays : const [],
                    repeatUntil: effectiveRecurrence == 'weekly' ? repeatUntil : null,
                    clearRepeatUntil: effectiveRecurrence != 'weekly' || repeatUntil == null,
                    category: finalCategory,
                  );

                  // Igual que al eliminar: si el evento se repite, se
                  // pregunta si el cambio aplica solo a este día o a este
                  // y todos los que siguen.
                  if (existing.isRecurring) {
                    final scope = await _askEditScope(context);
                    if (scope == null || !context.mounted) return;
                    if (scope == 'one') {
                      await dbHelper.updateEventOccurrence(existing, updated, date, linkedHabitIds: linkedHabitIds);
                    } else {
                      await dbHelper.updateEventFromDateOnward(existing, updated, date, linkedHabitIds: linkedHabitIds);
                    }
                  } else {
                    await dbHelper.updateEvent(updated, linkedHabitIds: linkedHabitIds);
                  }
                }
                if (context.mounted) Navigator.pop(context);
                onSaved();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );
}