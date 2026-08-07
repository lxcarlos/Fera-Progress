import 'dart:async';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calendar_event.dart';
import '../constants/categories.dart';
import '../utils/date_utils.dart';
import '../utils/calendar_zoom.dart';
import '../utils/app_events.dart';
import '../utils/event_layout.dart';
import 'event_dialog.dart';

const double kHourLabelWidth = 42.0;

// Cuadrícula de arrastre: al mover un evento con el dedo, su nueva hora
// siempre se ajusta a este número de minutos (15) para que quede en punto,
// y media hora, y cuarto — nunca "al minuto" exacto.
const int kDragSnapMinutes = 15;

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

  // El alto de cada hora ahora vive en un controlador compartido
  // (CalendarZoom) para que el zoom se mantenga igual entre día/semana.
  double get _hourHeight => CalendarZoom.hourHeight.value;

  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDistance;
  double? _pinchStartHourHeight;
  double? _pinchFocalScreenY;
  double? _pinchStartScrollOffset;

  // ---- Arrastrar (mantener pulsado) para mover un evento de horario ----
  int? _draggingEventId;
  double? _dragOrigTop;
  double? _dragStartGlobalY;
  double? _dragCurrentTop;
  int? _dragSnappedStartMin;

  bool get _isToday => isSameDate(widget.date, DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
    CalendarZoom.hourHeight.addListener(_onZoomChanged);
    AppEvents.tick.addListener(_onExternalChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isToday && _scrollController.hasClients) {
        final hour = DateTime.now().hour;
        _scrollController.jumpTo((hour - 1).clamp(0, 23) * _hourHeight);
      }
    });
    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onZoomChanged() {
    if (mounted) setState(() {});
  }

  // Cuando algo cambia en cualquier otra pantalla (por ejemplo, marcas un
  // hábito como completado desde la pestaña de Hábitos y ese hábito está
  // vinculado a un evento de hoy), este widget recarga solo, al instante,
  // sin que el usuario tenga que salir y volver a entrar.
  void _onExternalChange() {
    if (mounted) _load();
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
    CalendarZoom.hourHeight.removeListener(_onZoomChanged);
    AppEvents.tick.removeListener(_onExternalChange);
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

  String _formatMinutes(int totalMin) {
    final h = (totalMin ~/ 60).clamp(0, 23);
    final m = totalMin % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  void _showHiddenOverlapNotice(int hiddenCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hiddenCount == 1
              ? 'Hay 1 evento más en este horario que no se puede mostrar. Agrégalo en la descripción de uno de los eventos.'
              : 'Hay $hiddenCount eventos más en este horario que no se pueden mostrar. Agrégalos en la descripción de uno de los eventos.',
        ),
      ),
    );
  }

  Future<void> _moveEvent(CalendarEvent event, int newStartMin, int durationMin) async {
    final newStart = _formatMinutes(newStartMin);
    final newEnd = _formatMinutes(newStartMin + durationMin);
    await _dbHelper.moveEventOccurrence(event, widget.date, newStart, newEnd);
    _load();
    widget.onChanged?.call();
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
    // Un solo método aplica el cambio al evento Y a todos los hábitos/tareas
    // vinculados (puede haber varios) en la misma operación, al instante.
    await _dbHelper.toggleEventCompletion(event.id!, widget.date, completed: !current);
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
      CalendarZoom.setHeight(newHeight);
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

  // Contenido del bloque de evento, adaptado según el alto disponible para
  // que NUNCA se desborde. Al alejar el zoom, primero se oculta la hora,
  // luego el ícono, luego el título por completo (dejando solo el color),
  // y además todo el bloque va envuelto en un OverflowBox/ClipRect (ver
  // más abajo) como red de seguridad final: pase lo que pase con el
  // contenido, JAMÁS puede pintar fuera de su propio bloque ni disparar el
  // aviso de "BOTTOM OVERFLOWED".
  Widget _buildEventContent({
    required BuildContext context,
    required CalendarEvent event,
    required double height,
    required Color color,
    required bool completed,
    required ThemeData theme,
  }) {
    final catData = kCategories[event.category] ?? kCategories['general']!;

    if (height < 16) {
      // Demasiado chico: solo la barra de color, sin texto ni ícono.
      return const SizedBox.shrink();
    }

    final showIcon = height >= 30;
    final showSubtitle = height >= 46;
    final showCheck = height >= 24;
    final titleFontSize = height < 24 ? 10.0 : 12.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) ...[
                    Icon(catData['icon'] as IconData, size: 11, color: color),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      event.title,
                      maxLines: height > 40 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        decoration: completed ? TextDecoration.lineThrough : null,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              if (showSubtitle)
                Text(event.startTime + (event.endTime != null ? ' - ${event.endTime}' : ''),
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 10, height: 1.0)),
            ],
          ),
        ),
        if (showCheck)
          GestureDetector(
            onTap: () => _toggleComplete(event),
            child: Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: _isToday ? color : color.withOpacity(0.4),
            ),
          ),
      ],
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final areaWidth = constraints.maxWidth;
                          return Stack(
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
                              ...layoutEvents(_events).map((pos) {
                                final event = pos.event;
                                final startMin = _minutesFromMidnight(event.startTime);
                                final endMin = event.endTime != null ? _minutesFromMidnight(event.endTime!) : startMin + 30;
                                final durationMin = (endMin - startMin).clamp(20, 24 * 60).toInt();
                                final baseTop = startMin / 60 * _hourHeight;
                                final height = durationMin / 60 * _hourHeight;
                                final color = categoryAccent(context, event.category);
                                final completed = _completion[event.id] ?? false;
                                final vPad = height < 26 ? 1.0 : 4.0;

                                final isDragging = _draggingEventId == event.id;
                                final top = isDragging && _dragCurrentTop != null ? _dragCurrentTop! : baseTop;

                                // Reparte el ancho disponible entre las columnas del
                                // grupo de eventos que se solapan en este horario.
                                const hGap = 3.0;
                                final slotWidth = (areaWidth - 8 - hGap * (pos.columnCount - 1)) / pos.columnCount;
                                final left = 4 + pos.column * (slotWidth + hGap);

                                return Positioned(
                                  top: top,
                                  left: left,
                                  width: slotWidth,
                                  height: height,
                                  child: GestureDetector(
                                    onTap: () => _openEventDialog(existing: event),
                                    // Mantener pulsado para mover el evento: la hora de
                                    // inicio y fin se recalculan al soltar, siempre
                                    // ajustadas a bloques de 15 minutos.
                                    onLongPressStart: (details) {
                                      setState(() {
                                        _draggingEventId = event.id;
                                        _dragOrigTop = baseTop;
                                        _dragStartGlobalY = details.globalPosition.dy;
                                        _dragCurrentTop = baseTop;
                                        _dragSnappedStartMin = startMin;
                                      });
                                    },
                                    onLongPressMoveUpdate: (details) {
                                      if (_draggingEventId != event.id || _dragOrigTop == null || _dragStartGlobalY == null) return;
                                      final deltaY = details.globalPosition.dy - _dragStartGlobalY!;
                                      final rawTop = _dragOrigTop! + deltaY;
                                      final rawMinutes = rawTop / _hourHeight * 60;
                                      var snappedMin = (rawMinutes / kDragSnapMinutes).round() * kDragSnapMinutes;
                                      final maxStart = 24 * 60 - durationMin;
                                      snappedMin = snappedMin.clamp(0, maxStart < 0 ? 0 : maxStart).toInt();
                                      setState(() {
                                        _dragSnappedStartMin = snappedMin;
                                        _dragCurrentTop = snappedMin / 60 * _hourHeight;
                                      });
                                    },
                                    onLongPressEnd: (details) {
                                      final snapped = _dragSnappedStartMin;
                                      final wasDraggingThis = _draggingEventId == event.id;
                                      setState(() {
                                        _draggingEventId = null;
                                        _dragOrigTop = null;
                                        _dragStartGlobalY = null;
                                        _dragCurrentTop = null;
                                        _dragSnappedStartMin = null;
                                      });
                                      if (wasDraggingThis && snapped != null && snapped != startMin) {
                                        _moveEvent(event, snapped, durationMin);
                                      }
                                    },
                                    child: Container(
                                      clipBehavior: Clip.hardEdge,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: vPad),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(completed ? 0.12 : (isDragging ? 0.34 : 0.22)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: color.withOpacity(isDragging ? 0.9 : 0.6), width: isDragging ? 2 : 1),
                                        boxShadow: isDragging
                                            ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))]
                                            : null,
                                      ),
                                      // Red de seguridad final anti-overflow: ClipRect recorta
                                      // cualquier pixel que se salga y OverflowBox le permite al
                                      // contenido pedir el alto que quiera sin que Flutter dispare
                                      // el aviso rojo/negro de "BOTTOM OVERFLOWED".
                                      child: ClipRect(
                                        child: OverflowBox(
                                          alignment: Alignment.topLeft,
                                          minHeight: 0,
                                          maxHeight: double.infinity,
                                          child: Stack(
                                            children: [
                                              _buildEventContent(
                                                context: context,
                                                event: event,
                                                height: height,
                                                color: color,
                                                completed: completed,
                                                theme: theme,
                                              ),
                                              // Aviso de que hay más eventos en este mismo
                                              // horario de los que caben (más de 3): se
                                              // recomienda ponerlos en la descripción.
                                              if (pos.hiddenCount > 0)
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: GestureDetector(
                                                    onTap: () => _showHiddenOverlapNotice(pos.hiddenCount),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                                      child: Text('+${pos.hiddenCount}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
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