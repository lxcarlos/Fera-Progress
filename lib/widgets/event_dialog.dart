import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../models/habit.dart';
import '../constants/categories.dart';
import 'glass_dialog.dart';
import 'glass_picker.dart';

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
  int? linkedHabitId = existing?.linkedHabitId;

  const recurrenceLabels = {
    'none': 'No repetir',
    'daily': 'Todos los días',
    'weekly': 'Cada semana',
    'monthly': 'Cada mes',
  };

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        Habit? linkedHabit;
        if (linkedHabitId != null) {
          final matches = habits.where((h) => h.id == linkedHabitId);
          linkedHabit = matches.isEmpty ? null : matches.first;
        }

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
                label: 'Vincular a hábito/tarea',
                valueLabel: linkedHabit?.name ?? 'Sin vincular',
                valueIcon: linkedHabit != null ? Icons.link : Icons.link_off,
                onTap: () async {
                  final result = await showGlassPicker<int?>(
                    context,
                    title: 'Vincular a hábito/tarea',
                    selected: linkedHabitId,
                    options: [
                      const GlassPickerOption<int?>(value: null, label: 'Sin vincular', icon: Icons.link_off),
                      ...habits.map((h) => GlassPickerOption<int?>(value: h.id, label: h.name, icon: Icons.link)),
                    ],
                  );
                  setDialogState(() => linkedHabitId = result);
                },
              ),
              if (linkedHabitId == null) ...[
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
              ],
              const SizedBox(height: 10),
              GlassPickerField<String>(
                label: 'Repetir',
                valueLabel: recurrenceLabels[recurrence] ?? 'No repetir',
                valueIcon: Icons.repeat,
                onTap: () async {
                  final result = await showGlassPicker<String>(
                    context,
                    title: 'Repetir',
                    selected: recurrence,
                    options: recurrenceLabels.entries
                        .map((e) => GlassPickerOption<String>(value: e.key, label: e.value, icon: Icons.repeat))
                        .toList(),
                  );
                  if (result != null) setDialogState(() => recurrence = result);
                },
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await dbHelper.deleteEvent(existing.id!);
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

                String finalCategory = category;
                if (linkedHabitId != null) {
                  final match = habits.where((h) => h.id == linkedHabitId);
                  if (match.isNotEmpty) finalCategory = match.first.category;
                }

                if (existing == null) {
                  final event = CalendarEvent(
                    title: titleController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                    startTime: startStr,
                    endTime: endStr,
                    date: date,
                    recurrence: recurrence,
                    category: finalCategory,
                    linkedHabitId: linkedHabitId,
                    createdAt: DateTime.now(),
                  );
                  await dbHelper.createEvent(event);
                } else {
                  final updated = existing.copyWith(
                    title: titleController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                    startTime: startStr,
                    endTime: endStr,
                    recurrence: recurrence,
                    category: finalCategory,
                    linkedHabitId: linkedHabitId,
                    clearLink: linkedHabitId == null,
                  );
                  await dbHelper.updateEvent(updated);
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