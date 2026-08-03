import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../constants/categories.dart';
import '../utils/color_utils.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/mascot_widget.dart';
import 'settings_screen.dart';

const List<String> _kMotivationalPhrases = [
  'Cada día cuenta, aunque no lo sientas.',
  'El progreso real es silencioso.',
  'No se trata de ser perfecto, se trata de seguir.',
  'La constancia vence al talento.',
  'Un paso pequeño hoy es una ventaja mañana.',
  'Tu yo del futuro te lo va a agradecer.',
];

const List<Map<String, dynamic>> _kLevelStages = [
  {'range': 'Nivel 1-2', 'label': 'Semilla', 'icon': Icons.grass, 'desc': 'Estás empezando a plantar tus hábitos. Todo cuenta desde aquí.'},
  {'range': 'Nivel 3-5', 'label': 'Planta joven', 'icon': Icons.eco, 'desc': 'Tus hábitos empiezan a echar raíz. La constancia se está formando.'},
  {'range': 'Nivel 6-9', 'label': 'Árbol creciendo', 'icon': Icons.park, 'desc': 'Ya se nota. Lo que haces día a día empieza a dar frutos.'},
  {'range': 'Nivel 10+', 'label': 'Bosque pleno', 'icon': Icons.forest, 'desc': 'Tus hábitos ya son parte de quién eres, no una tarea pendiente.'},
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DBHelper _dbHelper = DBHelper();
  String _avatarName = 'Aventurero';
  int _totalPoints = 0;
  int _prevPoints = 0;
  Map<String, int> _categoryPoints = {};
  int _maxStreak = 0;
  int _totalCompletions = 0;
  bool _mascotJump = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final habits = await _dbHelper.getAllHabits();
    final categoryPoints = await _dbHelper.getPointsByCategory();
    final maxStreak = await _dbHelper.getMaxStreak();
    final totalCompletions = await _dbHelper.getTotalCompletions();
    final extraTotal = await _dbHelper.getExtraActivitiesTotalPoints();
    final newTotal = habits.where((h) => !h.isTask).fold(0, (sum, h) => sum + h.points) + extraTotal;

    setState(() {
      _avatarName = prefs.getString('avatar_name') ?? 'Aventurero';
      _prevPoints = _totalPoints;
      _totalPoints = newTotal;
      _categoryPoints = categoryPoints;
      _maxStreak = maxStreak;
      _totalCompletions = totalCompletions;
    });

    if (_totalPoints > _prevPoints) {
      setState(() => _mascotJump = true);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _mascotJump = false);
      });
    }
  }

  int get _level => (_totalPoints / 100).floor() + 1;

  String get _stageLabel {
    if (_level >= 10) return 'Bosque pleno';
    if (_level >= 6) return 'Árbol creciendo';
    if (_level >= 3) return 'Planta joven';
    return 'Semilla';
  }

  String get _streakLabel {
    if (_maxStreak == 0) return '';
    if (_maxStreak >= 21) return 'Hábito consolidado';
    return 'Construyendo persistencia';
  }

  String get _motivationalPhrase {
    if (_totalCompletions == 0) return _kMotivationalPhrases[0];
    return _kMotivationalPhrases[_totalCompletions % _kMotivationalPhrases.length];
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _avatarName);
    await showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: const Text('Nombre del avatar'),
        content: GlassField(controller: controller, hint: 'Tu nombre'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('avatar_name', controller.text.trim());
              if (context.mounted) Navigator.pop(context);
              _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: const Text('Manual de niveles'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._kLevelStages.map((stage) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                        child: Icon(stage['icon'] as IconData, color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(stage['label'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(width: 6),
                                Text('· ${stage['range']}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(stage['desc'] as String, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Text('Categorías', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Cada categoría representa un área de tu vida. Si una barra está muy baja comparada con las demás, esa es un área que quizás estás descuidando.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Text(
                '"El equilibrio no es hacerlo todo perfecto, es no abandonar ninguna parte de ti."',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85)),
              ),
            ),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];
    final maxCategoryValue = _categoryPoints.values.isEmpty ? 1 : _categoryPoints.values.reduce(max).clamp(1, 999999);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Perfil', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        leading: IconButton(icon: const Icon(Icons.info_outline), onPressed: _showInfo),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MascotWidget(level: _level, color: theme.colorScheme.primary, size: 140, jump: _mascotJump),
                        const SizedBox(height: 14),
                        Text(_avatarName, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _editName,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 13, color: contrastColor(theme.colorScheme.primary, isDark)),
                                const SizedBox(width: 5),
                                Text('Editar nombre', style: TextStyle(color: contrastColor(theme.colorScheme.primary, isDark), fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_stageLabel, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statBox('Nivel', '$_level', theme),
                            _statBox('Puntos', '$_totalPoints', theme),
                            _statBox('Racha máx.', '$_maxStreak días', theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_maxStreak > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_streakLabel, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(
                                  _maxStreak >= 21 ? 'Llevas $_maxStreak días seguidos. Esto ya es un hábito real.' : 'Llevas $_maxStreak días seguidos. Sigue así para consolidarlo.',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Categorías', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 14),
                        ...kCategories.entries.where((e) => e.key != 'general').map((entry) {
                          final points = _categoryPoints[entry.key] ?? 0;
                          final progress = points / maxCategoryValue;
                          final color = contrastColor(entry.value['color'] as Color, isDark);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(entry.value['icon'] as IconData, size: 15, color: color),
                                    const SizedBox(width: 6),
                                    Text(entry.value['label'] as String, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 13)),
                                    const Spacer(),
                                    Text('$points pts', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0, 1),
                                    minHeight: 6,
                                    backgroundColor: theme.colorScheme.onSurface.withOpacity(0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                    ),
                    child: Text(
                      _motivationalPhrase,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }
}