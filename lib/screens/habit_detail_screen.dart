import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../constants/categories.dart';
import '../database/db_helper.dart';
import '../services/notification_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_picker.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];

    return Scaffold(
      appBar: AppBar(title: const Text('Editar hábito')),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassField(controller: _nameController, hint: 'Nombre'),
              const SizedBox(height: 12),
              GlassField(controller: _descController, hint: 'Descripción (opcional)', maxLength: 140, maxLines: 3),
              const SizedBox(height: 12),
              GlassPickerField<String>(
                label: 'Categoría',
                valueLabel: (kCategories[_category] ?? kCategories['general']!)['label'] as String,
                valueIcon: (kCategories[_category] ?? kCategories['general']!)['icon'] as IconData,
                valueColor: categoryAccent(context, _category),
                onTap: () async {
                  final result = await showGlassPicker<String>(
                    context,
                    title: 'Categoría',
                    selected: _category,
                    options: kCategories.entries
                        .map((e) => GlassPickerOption<String>(
                              value: e.key,
                              label: e.value['label'] as String,
                              icon: e.value['icon'] as IconData,
                              color: categoryAccent(context, e.key),
                            ))
                        .toList(),
                  );
                  if (result != null) setState(() => _category = result);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _timeLimit == null ? 'Sin hora límite' : 'Hora límite: ${_timeLimit!.format(context)}',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                 


                  TextButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      final t = await showTimePicker(context: context, initialTime: _timeLimit ?? TimeOfDay.now());
                      if (t != null) setState(() => _timeLimit = t);
                    },
                    child: const Text('Elegir'),
                  ),









                  if (_timeLimit != null)
                    IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _timeLimit = null)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueDate == null ? 'Sin fecha límite' : 'Fecha límite: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                  
                  



                  TextButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
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
                    IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _dueDate = null)),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Guardar cambios')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}