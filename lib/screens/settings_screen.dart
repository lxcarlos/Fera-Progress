import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/dynamic_accent.dart';
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
          const Text('Estilo visual del acento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Personaliza la animación y comportamiento de la luz en la app.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStyleChip(
                context: context,
                title: 'Estático',
                icon: Icons.palette_outlined,
                style: AppVisualStyle.staticColor,
                current: themeProvider.visualStyle,
                onTap: () => themeProvider.setVisualStyle(AppVisualStyle.staticColor),
              ),
              _buildStyleChip(
                context: context,
                title: 'Tron Neón',
                icon: Icons.bolt_rounded,
                style: AppVisualStyle.tron,
                current: themeProvider.visualStyle,
                onTap: () => themeProvider.setVisualStyle(AppVisualStyle.tron),
              ),
              _buildStyleChip(
                context: context,
                title: 'Latido',
                icon: Icons.favorite_rounded,
                style: AppVisualStyle.pulse,
                current: themeProvider.visualStyle,
                onTap: () => themeProvider.setVisualStyle(AppVisualStyle.pulse),
              ),
              _buildStyleChip(
                context: context,
                title: 'Onda',
                icon: Icons.waves_rounded,
                style: AppVisualStyle.wave,
                current: themeProvider.visualStyle,
                onTap: () => themeProvider.setVisualStyle(AppVisualStyle.wave),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Color de la app', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Elige un color para tu estilo, activa el modo Rainbow RGB o quita el color por completo.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Botón 1: Sin color (Monocromático / Desactivado)
              _buildMonochromeButton(context, themeProvider),
              // Botón 2: Rainbow RGB
              _buildRainbowButton(context, themeProvider),
              // Separador visual fino
              Container(width: 1, height: 32, color: Theme.of(context).dividerColor.withOpacity(0.2)),
              // Paleta de colores seleccionables
              ...ThemeProvider.presetColors.map((color) {
                final isSelected = !themeProvider.isMonochrome &&
                    !themeProvider.isRainbow &&
                    themeProvider.seedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => themeProvider.setSeedColor(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.55), blurRadius: 10, spreadRadius: 1)]
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),
          // Live Preview Card
          _buildLivePreviewCard(context, themeProvider),
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

  Widget _buildStyleChip({
    required BuildContext context,
    required String title,
    required IconData icon,
    required AppVisualStyle style,
    required AppVisualStyle current,
    required VoidCallback onTap,
  }) {
    final isSelected = style == current;
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.18) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primary : Theme.of(context).dividerColor.withOpacity(0.2),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonochromeButton(BuildContext context, ThemeProvider themeProvider) {
    final isSelected = themeProvider.isMonochrome;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: 'Sin color (Monocromático)',
      child: GestureDetector(
        onTap: () => themeProvider.disableColor(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: isDark ? Colors.white : Colors.black, width: 2.5)
                : Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3), width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isSelected ? Icons.check : Icons.format_color_reset_outlined,
            size: 20,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildRainbowButton(BuildContext context, ThemeProvider themeProvider) {
    final isSelected = themeProvider.isRainbow;

    return Tooltip(
      message: 'Rainbow RGB (Dinámico)',
      child: GestureDetector(
        onTap: () => themeProvider.setVisualStyle(AppVisualStyle.rainbow),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFFF0055),
                Color(0xFFFF9900),
                Color(0xFFFFEE00),
                Color(0xFF00FF66),
                Color(0xFF00CCFF),
                Color(0xFF7700FF),
                Color(0xFFFF00CC),
                Color(0xFFFF0055),
              ],
            ),
            border: isSelected
                ? Border.all(color: Colors.white, width: 3)
                : Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Color(0x8800CCFF),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(BuildContext context, ThemeProvider themeProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DynamicAccentBuilder(
      controller: themeProvider.accentController,
      builder: (context, accent, glow) {
        final style = themeProvider.visualStyle;
        final isTron = style == AppVisualStyle.tron;
        final hasGlow = isTron || (glow > 2.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111113) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withOpacity(isTron ? (0.35 + (glow / 8.0) * 0.45) : 0.45),
              width: isTron ? (1.2 + (glow / 8.0) * 0.8) : 1.2,
            ),
            boxShadow: hasGlow
                ? [
                    BoxShadow(
                      color: accent.withOpacity(isTron ? 0.35 : 0.25),
                      blurRadius: glow * 1.5,
                      spreadRadius: glow * 0.2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.8),
                          blurRadius: isTron ? (glow * 1.2) : 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Previsualización: ${style.displayName}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withOpacity(0.6), width: 1),
                    ),
                    child: Text(
                      style.isAnimated ? 'En movimiento' : (style == AppVisualStyle.monochrome ? 'Sin tinte' : 'Fijo'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                style.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}