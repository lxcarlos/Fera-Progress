import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../database/db_helper.dart';
import '../constants/categories.dart';
import '../constants/design_tokens.dart';
import '../utils/color_utils.dart';
import '../utils/date_utils.dart';
import '../widgets/pulse_fire_icon.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_picker.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/day_percent_ring.dart';
import '../utils/app_events.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';
import 'habit_detail_screen.dart';
import 'habit_history_screen.dart';
import 'calendar_stats_screen.dart';

const Color kTaskColor = Color(0xFF60A5FA);

enum TypeFilter { all, done, notDone, tasks, extra }

String? _countdownText(Habit habit) {
  DateTime? deadline;
  if (habit.dueDate != null && habit.timeLimit != null) {
    final parts = habit.timeLimit!.split(':');
    deadline = DateTime(habit.dueDate!.year, habit.dueDate!.month, habit.dueDate!.day, int.parse(parts[0]), int.parse(parts[1]));
  } else if (habit.dueDate != null) {
    deadline = DateTime(habit.dueDate!.year, habit.dueDate!.month, habit.dueDate!.day, 23, 59);
  } else if (habit.timeLimit != null) {
    final now = DateTime.now();
    final parts = habit.timeLimit!.split(':');
    deadline = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }
  if (deadline == null) return null;
  final diff = deadline.difference(DateTime.now());
  if (diff.isNegative) return 'Vencido';
  if (diff.inDays >= 1) return 'Faltan ${diff.inDays} días';
  if (diff.inHours >= 1) return 'Faltan ${diff.inHours} h';
  return 'Faltan ${diff.inMinutes} min';
}

bool _isLate(Habit habit, DateTime? completedAt) {
  if (completedAt == null) return false;
  DateTime? deadline;
  if (habit.dueDate != null && habit.timeLimit != null) {
    final parts = habit.timeLimit!.split(':');
    deadline = DateTime(habit.dueDate!.year, habit.dueDate!.month, habit.dueDate!.day, int.parse(parts[0]), int.parse(parts[1]));
  } else if (habit.dueDate != null) {
    deadline = DateTime(habit.dueDate!.year, habit.dueDate!.month, habit.dueDate!.day, 23, 59);
  } else if (habit.timeLimit != null) {
    final parts = habit.timeLimit!.split(':');
    deadline = DateTime(completedAt.year, completedAt.month, completedAt.day, int.parse(parts[0]), int.parse(parts[1]));
  }
  if (deadline == null) return false;
  return completedAt.isAfter(deadline);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DBHelper _dbHelper = DBHelper();
  final StreakService _streakService = StreakService();

  List<Habit> _habits = [];
  List<Map<String, dynamic>> _extraActivities = [];
  Map<int, Map<String, dynamic>?> _dateRecords = {};
  int _extraPointsTotal = 0;
  DateTime _selectedDate = DateTime.now();
  StreakInfo _streakInfo = StreakInfo(0, 0);

  TypeFilter _typeFilter = TypeFilter.all;
  String? _categoryFilter;

  bool _dayFullyCompleted = false;
  bool _showCelebration = false;
  Key _celebrationKey = UniqueKey();

  double _todayHabitPercent = 0;
  bool _todayHasHabits = false;

  bool get _isToday => isSameDate(_selectedDate, DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadAll();
    AppEvents.tick.addListener(_onExternalChange);
  }

  @override
  void dispose() {
    AppEvents.tick.removeListener(_onExternalChange);
    super.dispose();
  }

  void _onExternalChange() {
    if (mounted) _loadAll();
  }

  bool _computeFullyCompleted() {
    if (!_isToday) return false;
    final relevant = _habits.where((h) => !h.isTask && !h.isPaused && !dateOnly(h.createdAt).isAfter(_selectedDate)).toList();
    if (relevant.isEmpty) return false;
    return relevant.every((h) {
      final r = _dateRecords[h.id];
      return r != null && r['completed'] == 1;
    });
  }

  void _triggerCelebration() {
    setState(() {
      _celebrationKey = UniqueKey();
      _showCelebration = true;
    });
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _showCelebration = false);
    });
  }

  Future<void> _loadAll() async {
    final habits = await _dbHelper.getAllHabits();
    final extras = _isToday ? await _dbHelper.getRecentExtraActivities(limit: 5) : <Map<String, dynamic>>[];
    final extraTotal = await _dbHelper.getExtraActivitiesTotalPoints();
    final streakInfo = await _streakService.getStreakInfo();

    final Map<int, Map<String, dynamic>?> records = {};
    for (final h in habits) {
      if (h.id != null) {
        records[h.id!] = await _dbHelper.getRecordForDate(h.id!, _selectedDate);
      }
    }

    final todayStatus = await _dbHelper.getHabitsStatusForDate(DateTime.now());
    final todayHabitsOnly = todayStatus.where((h) => h['isTask'] != true).toList();
    final todayPercent = todayHabitsOnly.isEmpty ? 0.0 : todayHabitsOnly.where((h) => h['completed'] == true).length / todayHabitsOnly.length;

    if (!mounted) return;
    setState(() {
      _habits = habits;
      _extraActivities = extras;
      _dateRecords = records;
      _extraPointsTotal = extraTotal;
      _streakInfo = streakInfo;
      _todayHasHabits = todayHabitsOnly.isNotEmpty;
      _todayHabitPercent = todayPercent;
    });

    final fullyCompletedNow = _computeFullyCompleted();
    if (fullyCompletedNow && !_dayFullyCompleted) {
      _triggerCelebration();
    }
    _dayFullyCompleted = fullyCompletedNow;
  }

  void _changeDate(int deltaDays) {
    final newDate = _selectedDate.add(Duration(days: deltaDays));
    if (newDate.isAfter(DateTime.now())) return;
    setState(() => _selectedDate = dateOnly(newDate));
    _loadAll();
  }

  int get _habitPoints => _habits.where((h) => !h.isTask).fold(0, (sum, h) => sum + h.points);
  int get _totalPoints => _habitPoints + _extraPointsTotal;
  int get _level => (_totalPoints / 100).floor() + 1;
  int get _pointsToNextLevel => (_level * 100) - _totalPoints;

  List<Habit> get _visibleHabitsForDate {
    return _habits.where((h) {
      final createdDay = dateOnly(h.createdAt);
      if (createdDay.isAfter(_selectedDate)) return false;
      if (!_isToday && h.isTask) return false;
      return true;
    }).toList();
  }

  List<Habit> get _filteredHabits {
    var list = _visibleHabitsForDate;

    if (_categoryFilter != null) {
      list = list.where((h) => h.category == _categoryFilter).toList();
    }

    switch (_typeFilter) {
      case TypeFilter.all:
        break;
      case TypeFilter.tasks:
        list = list.where((h) => h.isTask).toList();
        break;
      case TypeFilter.done:
        list = list.where((h) {
          final r = _dateRecords[h.id];
          return r != null && r['completed'] == 1;
        }).toList();
        break;
      case TypeFilter.notDone:
        list = list.where((h) {
          final r = _dateRecords[h.id];
          return !(r != null && r['completed'] == 1);
        }).toList();
        break;
      case TypeFilter.extra:
        list = [];
        break;
    }

    return list;
  }

  Future<void> _addHabit() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    TimeOfDay? selectedTime;
    DateTime? selectedDueDate;
    String selectedCategory = 'general';
    bool isTask = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = isTask ? kTaskColor : Theme.of(context).colorScheme.primary;
          return GlassDialog(
            title: Text(isTask ? 'Nueva tarea del día' : 'Nuevo hábito'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.repeat), label: Text('Hábito')),
                    ButtonSegment(value: true, icon: Icon(Icons.today), label: Text('Tarea del día')),
                  ],
                  selected: {isTask},
                  onSelectionChanged: (s) => setDialogState(() => isTask = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected) ? accent.withOpacity(0.25) : null),
                  ),
                ),
                const SizedBox(height: 14),
                GlassField(controller: nameController, hint: isTask ? 'Ej: Pagar el recibo de luz' : 'Ej: Ordenar mi cuarto'),
                const SizedBox(height: 10),
                GlassField(controller: descController, hint: 'Descripción (opcional)', maxLength: 140, maxLines: 2),
                const SizedBox(height: 10),
                GlassPickerField<String>(
                  label: 'Categoría',
                  valueLabel: (kCategories[selectedCategory] ?? kCategories['general']!)['label'] as String,
                  valueIcon: (kCategories[selectedCategory] ?? kCategories['general']!)['icon'] as IconData,
                  valueColor: categoryAccent(context, selectedCategory),
                  onTap: () async {
                    final result = await showGlassPicker<String>(
                      context,
                      title: 'Categoría',
                      selected: selectedCategory,
                      options: kCategories.entries
                          .map((e) => GlassPickerOption<String>(
                                value: e.key,
                                label: e.value['label'] as String,
                                icon: e.value['icon'] as IconData,
                                color: categoryAccent(context, e.key),
                              ))
                          .toList(),
                    );
                    if (result != null) setDialogState(() => selectedCategory = result);
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text(selectedTime == null ? 'Sin hora límite' : 'Hora: ${selectedTime!.format(context)}')),
                   
                   
                   
                   
                   TextButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (time != null) setDialogState(() => selectedTime = time);
                      },
                      child: const Text('Elegir hora'),
                    ),





                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(selectedDueDate == null
                          ? 'Sin fecha límite'
                          : 'Fecha: ${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}'),
                    ),
                   

                   TextButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) setDialogState(() => selectedDueDate = date);
                      },
                      child: const Text('Elegir fecha'),
                    ),


                  ],
                ),
                if (isTask)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Las tareas del día no otorgan puntos ni afectan tu racha.',
                        style: TextStyle(color: kTaskColor.withOpacity(0.9), fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;

                  final habit = Habit(
                    name: nameController.text.trim(),
                    frequency: 'daily',
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                    timeLimit: selectedTime != null
                        ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                        : null,
                    dueDate: selectedDueDate,
                    createdAt: DateTime.now(),
                    category: selectedCategory,
                    isTask: isTask,
                  );

                  final newId = await _dbHelper.createHabit(habit);
                  final habitWithId = Habit(
                    id: newId,
                    name: habit.name,
                    frequency: habit.frequency,
                    timeLimit: habit.timeLimit,
                    dueDate: habit.dueDate,
                    description: habit.description,
                    createdAt: habit.createdAt,
                    category: habit.category,
                    isTask: habit.isTask,
                  );
                  await NotificationService().scheduleForHabit(habitWithId);

                  if (context.mounted) Navigator.pop(context);
                  _loadAll();
                },
                child: Text(isTask ? 'Crear tarea' : 'Crear hábito'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addExtraActivity() async {
    final descController = TextEditingController();
    String selectedCategory = 'general';
    int selectedPoints = 1;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: const Text('Actividad extra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassField(controller: descController, hint: 'Ej: Ayudé a un amigo'),
              const SizedBox(height: 12),
              GlassPickerField<String>(
                label: 'Categoría',
                valueLabel: (kCategories[selectedCategory] ?? kCategories['general']!)['label'] as String,
                valueIcon: (kCategories[selectedCategory] ?? kCategories['general']!)['icon'] as IconData,
                valueColor: categoryAccent(context, selectedCategory),
                onTap: () async {
                  final result = await showGlassPicker<String>(
                    context,
                    title: 'Categoría',
                    selected: selectedCategory,
                    options: kCategories.entries
                        .map((e) => GlassPickerOption<String>(
                              value: e.key,
                              label: e.value['label'] as String,
                              icon: e.value['icon'] as IconData,
                              color: categoryAccent(context, e.key),
                            ))
                        .toList(),
                  );
                  if (result != null) setDialogState(() => selectedCategory = result);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Puntos: '),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: selectedPoints,
                    items: [1, 2, 3, 5, 8].map((p) => DropdownMenuItem(value: p, child: Text('$p'))).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedPoints = value);
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Se elimina automáticamente al día siguiente (los puntos ya ganados se conservan).',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (descController.text.trim().isEmpty) return;
                await _dbHelper.createExtraActivity(
                  description: descController.text.trim(),
                  points: selectedPoints,
                  category: selectedCategory,
                );
                if (context.mounted) Navigator.pop(context);
                _loadAll();
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassDialog(
        title: const Text('¿Eliminar?'),
        content: Text(
          '¿Seguro que quieres eliminar "${habit.name}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && habit.id != null) {
      await _dbHelper.deleteHabit(habit.id!);
      await NotificationService().cancelForHabit(habit.id);
      _loadAll();
    }
  }

  Future<void> _deleteExtraActivity(int id) async {
    await _dbHelper.deleteExtraActivity(id);
    _loadAll();
  }

  Future<void> _editHabit(Habit habit) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit)));
    if (result == true) _loadAll();
  }

  void _openHistory(Habit habit) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HabitHistoryScreen(habit: habit)));
  }

  Future<void> _toggleHabitCompletion(Habit habit) async {
    if (!_isToday || habit.isPaused || habit.id == null) return;
    final today = DateTime.now();
    final record = _dateRecords[habit.id];
    final isCompleted = record != null && record['completed'] == 1;

    if (isCompleted) {
      await _dbHelper.unmarkHabitCompletion(habit.id!, today);
      if (!habit.isTask) {
        final newPoints = (habit.points - 1) < 0 ? 0 : habit.points - 1;
        final newStreak = (habit.currentStreak - 1) < 0 ? 0 : habit.currentStreak - 1;
        await _dbHelper.updateHabit(habit.copyWith(points: newPoints, currentStreak: newStreak));
      }
    } else {
      await _dbHelper.markHabitCompletion(habit.id!, today, true);
      if (!habit.isTask) {
        final yesterday = today.subtract(const Duration(days: 1));
        final wasYesterdayCompleted = await _dbHelper.wasCompletedOn(habit.id!, yesterday);
        final newStreak = wasYesterdayCompleted ? habit.currentStreak + 1 : 1;
        final newBestStreak = newStreak > habit.bestStreak ? newStreak : habit.bestStreak;
        await _dbHelper.updateHabit(habit.copyWith(points: habit.points + 1, currentStreak: newStreak, bestStreak: newBestStreak));
      }
    }
    _loadAll();
  }

  Future<void> _togglePause(Habit habit) async {
    final updated = habit.copyWith(isPaused: !habit.isPaused);
    await _dbHelper.updateHabit(updated);
    await NotificationService().scheduleForHabit(updated);
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];
    final habits = _filteredHabits;

    return Stack(
      children: [
       
       Scaffold(
          appBar: AppBar(


            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Desarrollo personal', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.1, fontSize: 17)),
                const SizedBox(width: 10),
                // Bolita de % de hábitos cumplidos hoy: antes vivía en la
                // tarjeta de racha, ahora queda junto al título y, del otro
                // lado, junto al rayito de "Actividad extra".
                DayPercentRing(
                  percent: _todayHabitPercent,
                  hasData: _todayHasHabits,
                  size: 26,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CalendarStatsScreen(selectedDay: DateTime.now())),
                  ).then((_) => _loadAll()),
                ),
              ],
            ),
            actions: [
              if (_isToday) IconButton(icon: const Icon(Icons.bolt), tooltip: 'Actividad extra', onPressed: _addExtraActivity),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
            child: SafeArea(
              



              
              
              child: Column(
                children: [
                  // Se quitó el rectángulo de "racha + puntos" que iba
                  // hasta arriba. El Scaffold ya reserva el alto del
                  // AppBar automáticamente (sin extendBodyBehindAppBar),
                  // así que la fecha empieza pegada, sin espacio negro
                  // de más ni quedar tapada.
                  const SizedBox(height: 6),
                  _DateNav(date: _selectedDate, isToday: _isToday, onChange: _changeDate),







                  const SizedBox(height: 4),
                  _FilterRow(
                    typeFilter: _typeFilter,
                    categoryFilter: _categoryFilter,
                    onTypeChanged: (t) => setState(() => _typeFilter = t),
                    onCategoryChanged: (c) => setState(() => _categoryFilter = c),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      children: [
                        if (habits.isEmpty && (_extraActivities.isEmpty || !_isToday))
                          Padding(
                            padding: const EdgeInsets.only(top: 70),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.self_improvement, size: 52, color: theme.colorScheme.onSurface.withOpacity(0.15)),
                                  const SizedBox(height: 14),
                                  Text(
                                    _isToday ? 'Aún no tienes hábitos.\nCrea el primero.' : 'Sin hábitos registrados este día.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ...habits.map((habit) {
                          final record = _dateRecords[habit.id];
                          final isCompleted = record != null && record['completed'] == 1;
                          final completedAt = record != null && record['completedAt'] != null ? DateTime.parse(record['completedAt']) : null;
                          return _GlassCard(
                            habit: habit,
                            isCompletedToday: isCompleted,
                            isLate: _isLate(habit, completedAt),
                            countdown: isCompleted ? null : _countdownText(habit),
                            readOnly: !_isToday,
                            onDelete: () => _confirmDelete(habit),
                            onComplete: () => _toggleHabitCompletion(habit),
                            onTogglePause: () => _togglePause(habit),
                            onEdit: () => _editHabit(habit),
                            onOpenHistory: habit.isTask ? null : () => _openHistory(habit),
                          );
                        }),
                        if (_isToday && _extraActivities.isNotEmpty && _typeFilter != TypeFilter.tasks && _typeFilter != TypeFilter.done && _typeFilter != TypeFilter.notDone) ...[
                          const SizedBox(height: 8),
                          Text('Actividad extra de hoy',
                              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          ..._extraActivities
                              .where((a) => _categoryFilter == null || a['category'] == _categoryFilter)
                              .map((activity) => _ExtraActivityCard(
                                    description: activity['description'] as String,
                                    points: activity['points'] as int,
                                    category: activity['category'] as String,
                                    onDelete: () => _deleteExtraActivity(activity['id'] as int),
                                  )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: _isToday
              ? FloatingActionButton(
                  onPressed: _addHabit,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.add, color: Colors.black),
                )
              : null,
        ),
        if (_showCelebration) CelebrationOverlay(key: _celebrationKey, color: theme.colorScheme.primary),
      ],
    );
  }
}

class _DateNav extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final void Function(int deltaDays) onChange;

  const _DateNav({required this.date, required this.isToday, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => onChange(-1)),
          Text(
            isToday ? 'Hoy · ${formatDayMonth(date)}' : formatDayMonth(date),
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isToday ? null : () => onChange(1),
            color: isToday ? theme.colorScheme.onSurface.withOpacity(0.2) : null,
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final TypeFilter typeFilter;
  final String? categoryFilter;
  final ValueChanged<TypeFilter> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;

  const _FilterRow({
    required this.typeFilter,
    required this.categoryFilter,
    required this.onTypeChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final typeOptions = <TypeFilter, IconData>{
      TypeFilter.all: Icons.apps,
      TypeFilter.done: Icons.check_circle_outline,
      TypeFilter.notDone: Icons.radio_button_unchecked,
      TypeFilter.tasks: Icons.today,
      TypeFilter.extra: Icons.bolt,
    };

    Widget iconChip({required bool selected, required IconData icon, required Color color, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color.withOpacity(0.18) : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.2),
          ),
          child: Icon(icon, size: 16, color: selected ? color : theme.colorScheme.onSurface.withOpacity(0.4)),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          ...typeOptions.entries.map((e) => iconChip(
                selected: typeFilter == e.key,
                icon: e.value,
                color: theme.colorScheme.primary,
                onTap: () => onTypeChanged(e.key),
              )),
          Container(width: 1, height: 24, color: theme.colorScheme.onSurface.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 4)),
          ...kCategories.entries.where((e) => e.key != 'general').map((e) {
            final color = categoryAccent(context, e.key);
            return iconChip(
              selected: categoryFilter == e.key,
              icon: e.value['icon'] as IconData,
              color: color,
              onTap: () => onCategoryChanged(categoryFilter == e.key ? null : e.key),
            );
          }),
        ],
      ),
    );
  }
}



class _GlassCard extends StatelessWidget {
  final Habit habit;
  final bool isCompletedToday;
  final bool isLate;
  final String? countdown;
  final bool readOnly;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final VoidCallback onTogglePause;
  final VoidCallback onEdit;
  final VoidCallback? onOpenHistory;

  const _GlassCard({
    required this.habit,
    required this.isCompletedToday,
    required this.isLate,
    required this.countdown,
    required this.readOnly,
    required this.onDelete,
    required this.onComplete,
    required this.onTogglePause,
    required this.onEdit,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catData = kCategories[habit.category] ?? kCategories['general']!;
    final accent = habit.isTask ? kTaskColor : theme.colorScheme.primary;
    final catAccent = categoryAccent(context, habit.category);

    return GestureDetector(
      onTap: onOpenHistory,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: habit.isPaused
                    ? (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02))
                    : catAccent.withOpacity(isDark ? 0.09 : 0.06),
                borderRadius: BorderRadius.circular(kCardRadius),
                border: Border.all(
                  color: habit.isTask ? accent.withOpacity(0.35) : catAccent.withOpacity(0.32),
                  width: habit.isTask ? 1 : 1.3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: (readOnly || habit.isPaused) ? null : onComplete,
                        child: AnimatedScale(
                          scale: isCompletedToday ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: habit.isPaused
                                  ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))
                                  : (isCompletedToday ? accent.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04))),
                              border: Border.all(
                                color: habit.isPaused
                                    ? (isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2))
                                    : (isCompletedToday ? accent : theme.colorScheme.onSurface.withOpacity(0.25)),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isCompletedToday ? Icons.check : Icons.close,
                              size: 16,
                              color: habit.isPaused
                                  ? (isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2))
                                  : (isCompletedToday ? accent : theme.colorScheme.onSurface.withOpacity(0.3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(catData['icon'] as IconData, size: 13, color: catAccent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                habit.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: habit.isPaused ? theme.colorScheme.onSurface.withOpacity(0.4) : theme.colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  decoration: habit.isPaused ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            if (habit.isTask) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: kTaskColor.withOpacity(0.18), borderRadius: BorderRadius.circular(kChipRadius)),
                                child: Text('tarea', style: TextStyle(color: kTaskColor, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!readOnly) ...[
                        IconButton(icon: Icon(Icons.edit, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 18), onPressed: onEdit),
                        IconButton(
                          icon: Icon(habit.isPaused ? Icons.play_arrow : Icons.pause, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 20),
                          onPressed: onTogglePause,
                        ),
                        IconButton(icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 20), onPressed: onDelete),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (!habit.isTask)
                          Text('Puntos: ${habit.points}', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                        if (!habit.isTask && habit.currentStreak > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department, size: 12, color: Colors.orange),
                              const SizedBox(width: 2),
                              Text('${habit.currentStreak} días', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                            ],
                          ),
                        if (countdown != null && !readOnly)
                          Text(countdown!,
                              style: TextStyle(
                                color: countdown == 'Vencido' ? Colors.red.withOpacity(0.8) : theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 12,
                              )),
                        if (isLate)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.watch_later_outlined, size: 12, color: Colors.orange.withOpacity(0.8)),
                              const SizedBox(width: 2),
                              Text('Con retraso', style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 12)),
                            ],
                          ),
                        if (habit.isPaused && !readOnly)
                          Text('Pausado', style: TextStyle(color: Colors.orange.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtraActivityCard extends StatelessWidget {
  final String description;
  final int points;
  final String category;
  final VoidCallback onDelete;

  const _ExtraActivityCard({required this.description, required this.points, required this.category, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catAccent = categoryAccent(context, category);
    final primaryAccent = contrastColor(theme.colorScheme.primary, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(kCardRadius),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 16, color: catAccent),
                const SizedBox(width: 10),
                Expanded(child: Text(description, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 13))),
                Text('+$points', style: TextStyle(color: primaryAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 16),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}