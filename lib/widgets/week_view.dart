import 'dart:async';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../constants/categories.dart';
import '../utils/date_utils.dart';
import '../utils/calendar_zoom.dart';
import 'event_dialog.dart';

const double kWeekHourLabelWidth = 32.0;

const List<String> kWeekdayShort = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

DateTime weekStartFor(DateTime d) {
  final date = dateOnly(d);
  final diff = date.weekday % 7;
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
  Timer? _nowTimer;

  late DateTime _weekStart;
  Map<int, List<CalendarEvent>> _eventsByDayIndex = {};
  Map<String, bool> _completionByKey = {};

  // Mismo controlador global de zoom que usa DayAgenda: así el acercamiento
  // se mantiene igual sin importar si cambias de semana o de vista.
  double get _hourHeight => CalendarZoom.hourHeight.value;

  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDistance;
  double? _pinchStartHourHeight;
  double? _pinchFocalScreenY;
  double? _pinchStartScrollOffset;

  @override
  void initState() {
    super.initState();
    _weekStart = weekStartFor(widget.anchorDate);
    _load();
    CalendarZoom.hourHeight.addListener(_onZoomChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vController.hasClients) {
        final hour = DateTime.now().hour;
        _vController.jumpTo((hour - 1).clamp(0, 23) * _hourHeight);
      }
    });
    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onZoomChanged() {
    if (mounted) setState(() {});
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
    _vController.dispose();
    _nowTimer?.cancel();
    CalendarZoom.hourHeight.removeListener(_onZoomChanged);
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

  // ---- Zoom con dos dedos (igual que en la vista de Día) ----

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      final pts = _activePointers.values.toList();
      _pinchStartDistance = (pts[0] - pts[1]).distance;
      _pinchStartHourHeight = _hourHeight;
      _pinchFocalScreenY = (pts[0].dy + pts[1].dy) / 2;
      _pinchStartScrollOffset = _vController.hasClients ? _vController.offset : 0;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2 && _pinchStartDistance != null && _pinchStartDistance! > 4) {
      final pts = _activePointers.values.toList();
      final newDistance = (pts[0] - pts[1]).distance;
      final scale = newDistance / _pinchStartDistance!;
      final newHeight = (_pinchStartHourHeight! * scale).clamp(kMinHourHeight, kMaxHourHeight);
      final ratio = newHeight / _pinchStartHourHeight!;
      final contentPosBefore = _pinchStartScrollOffset! + _pinchFocalScreenY!;
      final contentPosAfter = contentPosBefore * ratio;
      final newOffset = contentPosAfter - _pinchFocalScreenY!;
      CalendarZoom.setHeight(newHeight);
      if (_vController.hasClients) {
        final maxExtent = _vController.position.maxScrollExtent;
        _vController.jumpTo(newOffset.clamp(0.0, maxExtent < 0 ? 0.0 : maxExtent));
      }
    }
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) _pinchStartDistance = null;
  }

  // Contenido del bloque de evento adaptado al alto disponible, igual
  // filosofía que en DayAgenda: evita el "BOTTOM OVERFLOWED" ocultando
  // primero el checkbox y, en bloques muy chicos, todo el texto.
  Widget _buildEventContent({
    required CalendarEvent event,
    required double height,
    required Color color,
    required bool completed,
    required bool isToday,
    required ThemeData theme,
    required VoidCallback onToggle,
  }) {
    if (height < 12) return const SizedBox.shrink();

    final showCheck = height >= 26;
    final fontSize = height < 20 ? 8.0 : 9.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Text(
            event.title,
            maxLines: height > 30 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (showCheck)
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 11,
              color: isToday ? color : color.withOpacity(0.4),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final hourHeight = _hourHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayColumnWidth = (constraints.maxWidth - kWeekHourLabelWidth) / 7;

        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: kWeekHourLabelWidth),
                ...List.generate(7, (i) {
                  final day = _weekStart.add(Duration(days: i));
                  final isToday = isSameDate(day, today);
                  return SizedBox(
                    width: dayColumnWidth,
                    child: Column(
                      children: [
                        Text(kWeekdayShort[i], style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                        const SizedBox(height: 2),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? theme.colorScheme.primary : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${day.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isToday ? Colors.white : theme.colorScheme.onSurface,
                              )),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            Divider(height: 14, color: theme.colorScheme.onSurface.withOpacity(0.08)),
            Expanded(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUpOrCancel,
                onPointerCancel: _onPointerUpOrCancel,
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  controller: _vController,
                  child: SizedBox(
                    height: 24 * hourHeight,
                    child: Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: kWeekHourLabelWidth,
                              child: Column(
                                children: List.generate(
                                  24,
                                  (h) => SizedBox(
                                    height: hourHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('${h.toString().padLeft(2, '0')}h',
                                          style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurface.withOpacity(0.35))),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ...List.generate(7, (i) {
                              final day = _weekStart.add(Duration(days: i));
                              final events = _eventsByDayIndex[i] ?? [];
                              return SizedBox(
                                width: dayColumnWidth,
                                height: 24 * hourHeight,
                                child: Stack(
                                  children: [
                                    Column(
                                      children: List.generate(
                                        24,
                                        (h) => GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _openDialog(day, presetTime: TimeOfDay(hour: h, minute: 0)),
                                          child: Container(
                                            height: hourHeight,
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
                                      final top = startMin / 60 * hourHeight;
                                      final durationMin = (endMin - startMin).clamp(20, 24 * 60);
                                      final height = durationMin / 60 * hourHeight;
                                      final color = categoryAccent(context, event.category);
                                      final completed = _completionByKey['${event.id}_${_dateKey(day)}'] ?? false;
                                      final isToday = isSameDate(day, today);
                                      final vPad = height < 20 ? 0.5 : 2.0;

                                      return Positioned(
                                        top: top,
                                        left: 2,
                                        right: 2,
                                        height: height,
                                        child: GestureDetector(
                                          onTap: () => _openDialog(day, existing: event),
                                          child: Container(
                                            clipBehavior: Clip.hardEdge,
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: vPad),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(completed ? 0.14 : 0.24),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: color.withOpacity(0.6)),
                                            ),
                                            child: _buildEventContent(
                                              event: event,
                                              height: height,
                                              color: color,
                                              completed: completed,
                                              isToday: isToday,
                                              theme: theme,
                                              onToggle: () => _toggleComplete(event, day),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                        Positioned(
                          top: (nowMinutes / 60 * hourHeight) - 1,
                          left: kWeekHourLabelWidth + dayColumnWidth * _todayIndex(today),
                          width: dayColumnWidth,
                          child: _todayIndex(today) >= 0
                              ? Row(
                                  children: [
                                    Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                    Expanded(child: Container(height: 1.5, color: Colors.red)),
                                  ],
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _todayIndex(DateTime today) {
    for (int i = 0; i < 7; i++) {
      if (isSameDate(_weekStart.add(Duration(days: i)), today)) return i;
    }
    return -1;
  }
}