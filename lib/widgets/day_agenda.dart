import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../models/habit.dart';
import '../constants/categories.dart';
import '../utils/date_utils.dart';
import 'glass_dialog.dart';

const double kHourHeight = 60.0;

class DayAgenda extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onChanged;
  const DayAgenda({super.key, required this.date, this.onChanged});

  @override
  State<DayAgenda> createState() => _DayAgendaState();
}

class _DayAgendaState extends State<DayAgenda> {
  final DBHelper _dbHelper = DBHelper();
  List<CalendarEvent> _events = [];
  Map<int, bool> _completion = {};
  List<Habit> _linkableHabits = [];
  final ScrollController _scrollController = ScrollController();

  bool get _isToday => isSameDate(widget.date, DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isToday && _scrollController.hasClients) {
        final hour = DateTime.now().hour;
        _scrollController.jumpTo((hour - 1).clamp(0, 23) * kHourHeight);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DayAgenda oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDate(oldWidget.date, widget.date)) _load();
  }

  Future<void> _load() async {
    final events = await _dbHelper.getEventsForDate(widget.date);
    final habits = await _dbHelper.getAllHabits();
    final Map<int, bool> completion = {};
    for (final e in events) {
      if (e.id != null) completion[e.id!] = await _dbHelper.getEventCompletion(e.id!, widget.date);
    }
    if (!mounted) return;
    setState(() {
      _events = events;
      _completion = completion;
      _linkableHabits = habits;
    });
  }

  int _minutesFromMidnight(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _openEventDialog({CalendarEvent? existing, TimeOfDay? presetTime}) async {
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
                    ..._linkableHabits.map((h) => DropdownMenuItem<int?>(value: h.id, child: Text(h.name))),
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
                    await _dbHelper.deleteEvent(existing.id!);
                    if (context.mounted) Navigator.pop(context);
                    _load();
                    widget.onChanged?.call();
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
                    final match = _linkableHabits.where((h) => h.id == linkedHabitId);
                    if (match.isNotEmpty) finalCategory = match.first.category;
                  }

                  if (existing == null) {
                    final event = CalendarEvent(
                      title: titleController.text.trim(),
                      description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                      startTime: startStr,
                      endTime: endStr,
                      date: widget.date,
                      recurrence: recurrence,
                      category: finalCategory,
                      linkedHabitId: linkedHabitId,
                      createdAt: DateTime.now(),
                    );
                    await _dbHelper.createEvent(event);
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
                    await _dbHelper.updateEvent(updated);
                  }
                  if (context.mounted) Navigator.pop(context);
                  _load();
                  widget.onChanged?.call();
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleComplete(CalendarEvent event) async {
    if (!_isToday || event.id == null) return;
    final current = _completion[event.id] ?? false;
    final newValue = !current;
    await _dbHelper.setEventCompletion(event.id!, widget.date, newValue);
    if (event.linkedHabitId != null) {
      await _dbHelper.setHabitCompletionWithEffects(event.linkedHabitId!, widget.date, newValue);
    }
    _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 520,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: List.generate(
                  24,
                  (h) => SizedBox(
                    height: kHourHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${h.toString().padLeft(2, '0')}:00',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.35))),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Stack(
                children: [
                  Column(
                    children: List.generate(
                      24,
                      (h) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openEventDialog(presetTime: TimeOfDay(hour: h, minute: 0)),
                        child: Container(
                          height: kHourHeight,
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.06))),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._events.map((event) {
                    final startMin = _minutesFromMidnight(event.startTime);
                    final endMin = event.endTime != null ? _minutesFromMidnight(event.endTime!) : startMin + 30;
                    final top = startMin / 60 * kHourHeight;
                    final durationMin = (endMin - startMin).clamp(20, 24 * 60);
                    final height = durationMin / 60 * kHourHeight;
                    final catData = kCategories[event.category] ?? kCategories['general']!;
                    final color = categoryAccent(context, event.category);
                    final completed = _completion[event.id] ?? false;

                    return Positioned(
                      top: top,
                      left: 4,
                      right: 4,
                      height: height,
                      child: GestureDetector(
                        onTap: () => _openEventDialog(existing: event),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(completed ? 0.12 : 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.6)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(catData['icon'] as IconData, size: 11, color: color),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            event.title,
                                            maxLines: height > 40 ? 2 : 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              decoration: completed ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (height > 36)
                                      Text(event.startTime + (event.endTime != null ? ' - ${event.endTime}' : ''),
                                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 10)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _toggleComplete(event),
                                child: Icon(
                                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: _isToday ? color : color.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}