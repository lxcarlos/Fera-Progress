import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _minutesBefore = 15;
  bool _loadingNotif = true;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final value = await NotificationService().getMinutesBefore();
    if (!mounted) return;
    setState(() {
      _minutesBefore = value;
      _loadingNotif = false;
    });
  }

  Future<void> _setMinutes(int minutes) async {
    setState(() => _minutesBefore = minutes);
    await NotificationService().setMinutesBefore(minutes);
  }

  String _labelFor(int minutes) {
    if (minutes < 0) return 'Desactivadas';
    if (minutes == 0) return 'Al momento';
    return '$minutes min antes';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Apariencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Oscuro')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android), label: Text('Sistema')),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (s) => themeProvider.setThemeMode(s.first),
          ),
          const SizedBox(height: 28),
          const Text('Color de la app', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: ThemeProvider.presetColors.map((color) {
              final selected = themeProvider.seedColor.value == color.value;
              return GestureDetector(
                onTap: () => themeProvider.setSeedColor(color),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)] : null,
                  ),
                  child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Avisa antes de que se cumpla el límite de un hábito con hora.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_loadingNotif)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            Column(
              children: kNotificationOffsetOptions.map((minutes) {
                final selected = _minutesBefore == minutes;
                return RadioListTile<int>(
                  value: minutes,
                  groupValue: _minutesBefore,
                  onChanged: (v) => _setMinutes(v!),
                  title: Text(_labelFor(minutes)),
                  secondary: Icon(
                    minutes < 0 ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                    color: selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}