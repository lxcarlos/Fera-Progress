import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../constants/categories.dart';
import '../utils/date_utils.dart';
import 'event_dialog.dart';

const double kWeekHourHeight = 56.0;
const double kWeekDayColumnWidth = 74.0;
const double kWeekHourLabelWidth = 38.0;

const List<String> kWeekdayShort = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

DateTime weekStartFor(DateTime d) {
  final date = dateOnly(d);
  // DateTime.weekday: lunes=1 ... domingo=7. Queremos que la semana
  // empiece en domingo, como en el ejemplo de Samsung Calendar.
  final diff = date.weekday % 7; // domingo -> 0
  return date.subtract(Duration(days: diff));
}

class WeekView extends StatefulWidget {
  final DateTime anchorDate;
  final VoidCallback? onChanged;
  const WeekView({super.key, required this.anchorDate, this.onChanged});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  final DBHelper _dbHelper = DBHelper();
  final ScrollController _vController = ScrollController();
  final ScrollController _hHeaderController = ScrollController();
  final ScrollController _hBodyController = ScrollController();

  late DateTime _weekStart;
  Map<int, List<CalendarEvent>> _eventsByDayIndex = {};
  Map<String, bool> _completionByKey = {};

  @override
  void initState() {
    super.initState();
    _weekStart = weekStartFor(widget.anchorDate);
    _load();
    _hBodyController.addListener(_syncHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vController.hasClients) {
        final hour = DateTime.now().hour;
        _vController.jumpTo((hour - 1).clamp(0, 23) * kWeekHourHeight);
      }
    });
  }

  void _syncHeader() {
    if (_hHeaderController.hasClients && _hHeaderController.offset != _hBodyController.offset) {
      _hHeaderController.jumpTo(_hBodyController.offset);
    }
  }

  @override
  void didUpdateWidget(covariant WeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newStart = weekStartFor(widget.anchorDate);
    if (!isSameDate(newStart, _weekStart)) {
      _weekStart = newStart;
      _load();
    }
  }

  @override
  void dispose() {
    _hBodyController.removeListener(_syncHeader);
    _vController.dispose();
    _hHeaderController.dispose();
    _hBodyController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> _load() async {
    final Map<int, List<CalendarEvent>> byDay = {};
    final Map<String, bool> completion = {};
    for (int i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      final events = await _dbHelper.getEventsForDate(day);
      byDay[i] = events;
      for (final e in events) {
        if (e.id != null) {
          completion['${e.id}_${_dateKey(day)}'] = await _dbHelper.getEventCompletion(e.id!, day);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _eventsByDayIndex = byDay;
      _completionByKey = completion;
    });
  }

  int _minutesFromMidnight(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _openDialog(DateTime day, {CalendarEvent? existing, TimeOfDay? presetTime}) async {
    await showEventDialog(
      context,
      dbHelper: _dbHelper,
      date: day,
      existing: existing,
      presetTime: presetTime,
      onSaved: () {
        _load();
        widget.onChanged?.call();
      },
    );
  }

  Future<void> _toggleComplete(CalendarEvent event, DateTime day) async {
    if (event.id == null) return;
    final key = '${event.id}_${_dateKey(day)}';
    final current = _completionByKey[key] ?? false;
    final newValue = !current;
    await _dbHelper.setEventCompletion(event.id!, day, newValue);
    if (event.linkedHabitId != null) {
      await _dbHelper.setHabitCompletionWithEffects(event.linkedHabitId!, day, newValue);
    }
    _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());

    return Column(
      children: [
        // Encabezado con los 7 días. Su scroll horizontal se mantiene
        // sincronizado con el de la cuadrícula de abajo (ver _syncHeader).
        Row(
          children: [
            const SizedBox(width: kWeekHourLabelWidth),
            Expanded(
              child: SingleChildScrollView(
                controller: _hHeaderController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: List.generate(7, (i) {
                    final day = _weekStart.add(Duration(days: i));
                    final isToday = isSameDate(day, today);
                    return SizedBox(
                      width: kWeekDayColumnWidth,
                      child: Column(
                        children: [
                          Text(kWeekdayShort[i], style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                          const SizedBox(height: 2),
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday ? theme.colorScheme.primary : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text('${day.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isToday ? Colors.white : theme.colorScheme.onSurface,
                                )),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        Divider(height: 16, color: theme.colorScheme.onSurface.withOpacity(0.08)),
        Expanded(
          child: SingleChildScrollView(
            controller: _vController,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: kWeekHourLabelWidth,
                  child: Column(
                    children: List.generate(
                      24,
                      (h) => SizedBox(
                        height: kWeekHourHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('${h.toString().padLeft(2, '0')}:00',
                              style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withOpacity(0.35))),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hBodyController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(7, (i) {
                        final day = _weekStart.add(Duration(days: i));
                        final events = _eventsByDayIndex[i] ?? [];
                        return SizedBox(
                          width: kWeekDayColumnWidth,
                          height: 24 * kWeekHourHeight,
                          child: Stack(
                            children: [
                              Column(
                                children: List.generate(
                                  24,
                                  (h) => GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openDialog(day, presetTime: TimeOfDay(hour: h, minute: 0)),
                                    child: Container(
                                      height: kWeekHourHeight,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.06)),
                                          left: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.05)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ...events.map((event) {
                                final startMin = _minutesFromMidnight(event.startTime);
                                final endMin = event.endTime != null ? _minutesFromMidnight(event.endTime!) : startMin + 30;
                                final top = startMin / 60 * kWeekHourHeight;
                                final durationMin = (endMin - startMin).clamp(20, 24 * 60);
                                final height = durationMin / 60 * kWeekHourHeight;
                                final color = categoryAccent(context, event.category);
                                final completed = _completionByKey['${event.id}_${_dateKey(day)}'] ?? false;
                                final isToday = isSameDate(day, today);

                                return Positioned(
                                  top: top,
                                  left: 2,
                                  right: 2,
                                  height: height,
                                  child: GestureDetector(
                                    onTap: () => _openDialog(day, existing: event),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(completed ? 0.14 : 0.24),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: color.withOpacity(0.6)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              event.title,
                                              maxLines: height > 30 ? 2 : 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onSurface,
                                                decoration: completed ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                          ),
                                          if (height > 26)
                                            GestureDetector(
                                              onTap: () => _toggleComplete(event, day),
                                              child: Icon(
                                                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                                                size: 11,
                                                color: isToday ? color : color.withOpacity(0.4),
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
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}