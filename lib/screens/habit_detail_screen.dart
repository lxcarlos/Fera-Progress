import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../constants/categories.dart';
import '../database/db_helper.dart';
import '../services/notification_service.dart';

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;
  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late String _category;
  TimeOfDay? _timeLimit;
  DateTime? _dueDate;
  final DBHelper _dbHelper = DBHelper();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit.name);
    _descController = TextEditingController(text: widget.habit.description ?? '');
    _category = widget.habit.category;
    _dueDate = widget.habit.dueDate;
    if (widget.habit.timeLimit != null) {
      final parts = widget.habit.timeLimit!.split(':');
      _timeLimit = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;

    final updated = widget.habit.copyWith(
      name: _nameController.text.trim(),
      category: _category,
      description: _descController.text.trim(),
      timeLimit: _timeLimit != null
          ? '${_timeLimit!.hour.toString().padLeft(2, '0')}:${_timeLimit!.minute.toString().padLeft(2, '0')}'
          : null,
      dueDate: _dueDate,
      clearTimeLimit: _timeLimit == null,
      clearDueDate: _dueDate == null,
    );

    await _dbHelper.updateHabit(updated);
    await NotificationService().scheduleForHabit(updated);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar hábito')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLength: 140,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: kCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['label']))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora límite'),
              subtitle: Text(_timeLimit == null ? 'Sin hora límite' : _timeLimit!.format(context)),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _timeLimit ?? TimeOfDay.now());
                      if (t != null) setState(() => _timeLimit = t);
                    },
                    child: const Text('Elegir'),
                  ),
                  if (_timeLimit != null)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _timeLimit = null)),
                ],
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha límite'),
              subtitle: Text(_dueDate == null ? 'Sin fecha límite' : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                    child: const Text('Elegir'),
                  ),
                  if (_dueDate != null)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _dueDate = null)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Guardar cambios')),
            ),
          ],
        ),
      ),
    );
  }
}