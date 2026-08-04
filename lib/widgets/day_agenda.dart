import 'dart:async';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../constants/categories.dart';
import '../utils/date_utils.dart';
import 'event_dialog.dart';

const double kDefaultHourHeight = 60.0;
const double kMinHourHeight = 28.0;
const double kMaxHourHeight = 160.0;
const double kHourLabelWidth = 42.0;

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
  final ScrollController _scrollController = ScrollController();
  Timer? _nowTimer;

  // Alto de cada hora, ajustable con el gesto de pellizcar (zoom).
  double _hourHeight = kDefaultHourHeight;

  // Seguimiento manual de los dedos activos para el pellizco. Se usa
  // Listener (no GestureDetector) para no pelearse con el scroll normal
  // de un dedo: Listener recibe los eventos de puntero sin "robarle" el
  // gesto de arrastre vertical al SingleChildScrollView.
  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDistance;
  double? _pinchStartHourHeight;
  double? _pinchFocalScreenY;
  double? _pinchStartScrollOffset;

  bool get _isToday => isSameDate(widget.date, DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isToday && _scrollController.hasClients) {
        final hour = DateTime.now().hour;
        _scrollController.jumpTo((hour - 1).clamp(0, 23) * _hourHeight);
      }
    });
    // Refresca la línea roja de "ahora" cada 30s sin recargar los eventos.
    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
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
    _nowTimer?.cancel();
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

  // ---- Zoom con dos dedos ----

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      final pts = _activePointers.values.toList();
      _pinchStartDistance = (pts[0] - pts[1]).distance;
      _pinchStartHourHeight = _hourHeight;
      _pinchFocalScreenY = (pts[0].dy + pts[1].dy) / 2;
      _pinchStartScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0;
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
      setState(() => _hourHeight = newHeight);
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(newOffset.clamp(0.0, maxExtent < 0 ? 0.0 : maxExtent));
      }
    }
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) _pinchStartDistance = null;
  }

  Widget _buildNowLine(ThemeData theme) {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final top = (minutes / 60 * _hourHeight) - 7;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: kHourLabelWidth,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          Expanded(child: Container(height: 1.5, color: Colors.red)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalHeight = 24 * _hourHeight;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUpOrCancel,
      onPointerCancel: _onPointerUpOrCancel,
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          height: totalHeight,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: kHourLabelWidth,
                    child: Column(
                      children: List.generate(
                        24,
                        (h) => SizedBox(
                          height: _hourHeight,
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
                      height: totalHeight,
                      child: Stack(
                        children: [
                          Column(
                            children: List.generate(
                              24,
                              (h) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openEventDialog(presetTime: TimeOfDay(hour: h, minute: 0)),
                                child: Container(
                                  height: _hourHeight,
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
                            final top = startMin / 60 * _hourHeight;
                            final durationMin = (endMin - startMin).clamp(20, 24 * 60);
                            final height = durationMin / 60 * _hourHeight;
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
              if (_isToday) _buildNowLine(theme),
            ],
          ),
        ),
      ),
    );
  }
}