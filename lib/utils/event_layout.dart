import '../models/calendar_event.dart';

/// Un evento ya con su columna asignada dentro de su grupo de eventos que
/// se solapan en el tiempo, para que Día y Semana los dibujen uno al lado
/// del otro en vez de encimados.
class PositionedEvent {
  final CalendarEvent event;
  final int column; // 0-based
  final int columnCount; // columnas visibles en este grupo (máx. kMaxEventColumns)
  final int hiddenCount; // eventos que no caben (más allá de kMaxEventColumns)

  const PositionedEvent({
    required this.event,
    required this.column,
    required this.columnCount,
    this.hiddenCount = 0,
  });
}

/// Máximo de columnas que se muestran lado a lado cuando varios eventos
/// caen en el mismo horario. La app ya evita que se cree un 4º evento
/// encimado (ver countOverlappingEvents/_confirmOverlapIfNeeded), así que
/// esto es sobre todo una red de seguridad visual para datos existentes.
const int kMaxEventColumns = 3;

int _startMin(CalendarEvent e) {
  final p = e.startTime.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

int _endMin(CalendarEvent e) {
  if (e.endTime == null) return _startMin(e) + 30;
  final p = e.endTime!.split(':');
  final m = int.parse(p[0]) * 60 + int.parse(p[1]);
  return m > _startMin(e) ? m : _startMin(e) + 30;
}

/// Agrupa eventos que se solapan en el tiempo y les asigna una columna a
/// cada uno (0, 1, 2...) para repartirlos en el mismo espacio horizontal
/// en vez de dibujarlos uno encima del otro.
List<PositionedEvent> layoutEvents(List<CalendarEvent> events) {
  final sorted = List<CalendarEvent>.from(events)..sort((a, b) => _startMin(a).compareTo(_startMin(b)));

  final List<PositionedEvent> result = [];
  int i = 0;
  while (i < sorted.length) {
    // Arma un grupo de eventos que se solapan (transitivamente) entre sí.
    final group = <CalendarEvent>[sorted[i]];
    int groupEnd = _endMin(sorted[i]);
    int j = i + 1;
    while (j < sorted.length && _startMin(sorted[j]) < groupEnd) {
      group.add(sorted[j]);
      final e = _endMin(sorted[j]);
      if (e > groupEnd) groupEnd = e;
      j++;
    }

    final visibleCount = group.length > kMaxEventColumns ? kMaxEventColumns : group.length;
    final hidden = group.length > kMaxEventColumns ? group.length - kMaxEventColumns : 0;
    for (int k = 0; k < group.length && k < kMaxEventColumns; k++) {
      result.add(PositionedEvent(
        event: group[k],
        column: k,
        columnCount: visibleCount,
        hiddenCount: (k == visibleCount - 1) ? hidden : 0,
      ));
    }
    i = j;
  }
  return result;
}