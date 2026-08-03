import 'dart:ui';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../widgets/day_agenda.dart';
import '../widgets/week_view.dart';
import '../widgets/month_view.dart';
import '../widgets/year_view.dart';
import '../widgets/event_dialog.dart';
import '../utils/date_utils.dart';

enum _CalView { day, week, month, year }

const List<String> _kWeekdayLong = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  final DBHelper _dbHelper = DBHelper();
  _CalView _view = _CalView.day;
  DateTime _focusedDate = DateTime.now();

  /// Se llama desde MainNav cada vez que se entra a esta pestaña.
  /// Las subvistas (Día/Semana/Mes/Año) recargan sus propios datos en su
  /// initState/didUpdateWidget, así que aquí basta con forzar un rebuild.
  Future<void> refresh() async {
    if (mounted) setState(() {});
  }

  void _goToDayView(DateTime date) {
    setState(() {
      _focusedDate = dateOnly(date);
      _view = _CalView.day;
    });
  }

  void _goToMonthView(DateTime date) {
    setState(() {
      _focusedDate = DateTime(date.year, date.month, 1);
      _view = _CalView.month;
    });
  }

  void _changeDay(int deltaDays) {
    setState(() => _focusedDate = _focusedDate.add(Duration(days: deltaDays)));
  }

  String _dayLabel(DateTime d) {
    final weekday = _kWeekdayLong[d.weekday - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${d.day} de ${_monthName(d.month)}';
  }

  String _weekLabel(DateTime anchor) {
    final start = weekStartFor(anchor);
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.day} - ${end.day} de ${_monthName(start.month)}';
    }
    return '${start.day} ${_monthName(start.month)} - ${end.day} ${_monthName(end.month)}';
  }

  static const List<String> _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  String _monthName(int m) => _months[m - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFF000000), const Color(0xFF0D0D0D)] : [const Color(0xFFF7F9F7), const Color(0xFFECF3ED)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _ViewSwitcher(value: _view, onChanged: (v) => setState(() => _view = v)),
              ),
              const SizedBox(height: 8),
              if (_view == _CalView.day) _dayNavHeader(theme),
              if (_view == _CalView.week) _weekNavHeader(theme),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _glassCard(isDark, child: _buildBody()),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      floatingActionButton: _view == _CalView.day
          ? FloatingActionButton(
              onPressed: () => showEventDialog(
                context,
                dbHelper: _dbHelper,
                date: _focusedDate,
                onSaved: () => setState(() {}),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _dayNavHeader(ThemeData theme) {
    final isToday = isSameDate(_focusedDate, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-1)),
          GestureDetector(
            onTap: () => setState(() => _focusedDate = DateTime.now()),
            child: Column(
              children: [
                Text(_dayLabel(_focusedDate), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
                if (!isToday) Text('Toca para ir a hoy', style: TextStyle(color: theme.colorScheme.primary, fontSize: 10)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(1)),
        ],
      ),
    );
  }

  Widget _weekNavHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-7)),
          Text(_weekLabel(_focusedDate), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(7)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case _CalView.day:
        return DayAgenda(key: ValueKey('day_${_focusedDate.toIso8601String()}'), date: _focusedDate, onChanged: () {});
      case _CalView.week:
        return WeekView(key: ValueKey('week_${weekStartFor(_focusedDate).toIso8601String()}'), anchorDate: _focusedDate, onChanged: () {});
      case _CalView.month:
        return MonthView(
          key: ValueKey('month_${_focusedDate.year}_${_focusedDate.month}'),
          anchorDate: _focusedDate,
          onEditDay: _goToDayView,
        );
      case _CalView.year:
        return YearView(
          key: ValueKey('year_${_focusedDate.year}'),
          anchorDate: _focusedDate,
          onOpenMonth: _goToMonthView,
        );
    }
  }

  Widget _glassCard(bool isDark, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  final _CalView value;
  final ValueChanged<_CalView> onChanged;
  const _ViewSwitcher({required this.value, required this.onChanged});

  static const _options = [
    (_CalView.day, 'Día'),
    (_CalView.week, 'Semana'),
    (_CalView.month, 'Mes'),
    (_CalView.year, 'Año'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: _options.map((opt) {
          final selected = value == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}