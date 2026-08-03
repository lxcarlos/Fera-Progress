import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../models/habit.dart';
import '../constants/categories.dart';
import 'glass_dialog.dart';

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

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
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
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                initialValue: linkedHabitId,
                decoration: const InputDecoration(labelText: 'Vincular a hábito/tarea', border: InputBorder.none),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sin vincular')),
                  ...habits.map((h) => DropdownMenuItem<int?>(value: h.id, child: Text(h.name))),
                ],
                onChanged: (value) => setDialogState(() => linkedHabitId = value),
              ),
              if (linkedHabitId == null) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Categoría', border: InputBorder.none),
                  items: kCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['label']))).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
              ],
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: recurrence,
                decoration: const InputDecoration(labelText: 'Repetir', border: InputBorder.none),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('No repetir')),
                  DropdownMenuItem(value: 'daily', child: Text('Todos los días')),
                  DropdownMenuItem(value: 'weekly', child: Text('Cada semana')),
                  DropdownMenuItem(value: 'monthly', child: Text('Cada mes')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => recurrence = value);
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