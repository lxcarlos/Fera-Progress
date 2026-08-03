import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../constants/categories.dart';
import '../utils/date_utils.dart';
import 'event_dialog.dart';

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
  // Un único ScrollController compartido: la columna de horas y la columna
  // de eventos viven dentro del MISMO SingleChildScrollView (ver build()),
  // así siempre se mueven exactamente igual al hacer scroll.
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final events = await _dbHelper.getEventsForDate(widget.date);
    final Map<int, bool> completion = {};
    for (final e in events) {
      if (e.id != null) completion[e.id!] = await _dbHelper.getEventCompletion(e.id!, widget.date);
    }
    if (!mounted) return;
    setState(() {
      _events = events;
      _completion = completion;
    });
  }

  int _minutesFromMidnight(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _openEventDialog({CalendarEvent? existing, TimeOfDay? presetTime}) async {
    await showEventDialog(
      context,
      dbHelper: _dbHelper,
      date: widget.date,
      existing: existing,
      presetTime: presetTime,
      onSaved: () {
        _load();
        widget.onChanged?.call();
      },
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

    // OJO: hour labels y eventos van dentro del MISMO SingleChildScrollView,
    // en un solo Row. Esto es lo que garantiza que las horas se muevan junto
    // con los bloques de eventos al hacer scroll (antes usaban dos scrolls
    // "sincronizados" por el mismo controller, pero cada uno con su propia
    // posición interna, y por eso las horas se quedaban fijas).
    return SingleChildScrollView(
      controller: _scrollController,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
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
          Expanded(
            child: SizedBox(
              height: 24 * kHourHeight,
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