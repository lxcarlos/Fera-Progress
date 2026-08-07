import '../models/calendar_event.dart';

/// Un evento ya con su columna asignada dentro de su grupo de eventos que
/// se solapan en el tiempo, para que Día y Semana los dibujen uno al lado
/// del otro en vez de encimados.
///
/// A diferencia de antes, un evento puede ocupar más de una columna
/// (columnSpan) cuando a su derecha hay espacio libre real, así los
/// eventos encajan "como piezas de lego" en vez de dejar huecos.
class PositionedEvent {
  final CalendarEvent event;
  final int column; // 0-based, columna donde empieza
  final int columnSpan; // cuántas columnas ocupa a lo ancho (>=1)
  final int columnCount; // total de columnas del grupo
  final int hiddenCount; // eventos que no caben (más allá de kMaxEventColumns)

  const PositionedEvent({
    required this.event,
    required this.column,
    required this.columnSpan,
    required this.columnCount,
    this.hiddenCount = 0,
  });
}

/// Máximo de eventos que se muestran lado a lado cuando varios caen en el
/// mismo horario. La app ya evita crear un 4º evento encimado (ver
/// countOverlappingEvents/_confirmOverlapIfNeeded), así que esto es sobre
/// todo una red de seguridad visual para datos existentes.
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

bool _overlap(CalendarEvent a, CalendarEvent b) => _startMin(a) < _endMin(b) && _endMin(a) > _startMin(b);

/// Agrupa eventos que se solapan en el tiempo, les asigna una columna
/// (algoritmo tipo "greedy interval graph coloring", el mismo que usa
/// Google Calendar) y luego expande cada evento hacia la derecha todo lo
/// que pueda sin chocar con otro, para que no queden huecos artificiales.
List<PositionedEvent> layoutEvents(List<CalendarEvent> events) {
  final sorted = List<CalendarEvent>.from(events)
    ..sort((a, b) {
      final byStart = _startMin(a).compareTo(_startMin(b));
      if (byStart != 0) return byStart;
      // A igual inicio, el más largo va primero: así define mejor las
      // columnas y los más cortos se acomodan alrededor.
      return (_endMin(b) - _startMin(b)).compareTo(_endMin(a) - _startMin(a));
    });

  final List<PositionedEvent> result = [];
  int i = 0;
  while (i < sorted.length) {
    // 1) Arma un grupo de eventos que se solapan (transitivamente) entre sí.
    final group = <CalendarEvent>[sorted[i]];
    int groupEnd = _endMin(sorted[i]);
    int j = i + 1;
    while (j < sorted.length && _startMin(sorted[j]) < groupEnd) {
      group.add(sorted[j]);
      final e = _endMin(sorted[j]);
      if (e > groupEnd) groupEnd = e;
      j++;
    }

    // Solo se muestran hasta kMaxEventColumns eventos; el resto se resume
    // como "+N" en el último visible.
    final visible = group.length > kMaxEventColumns ? group.sublist(0, kMaxEventColumns) : group;
    final hidden = group.length > kMaxEventColumns ? group.length - kMaxEventColumns : 0;

    // 2) Cada evento va a la primera columna donde quepa sin chocar con lo
    // que ya hay ahí.
    final List<List<CalendarEvent>> columns = [];
    final Map<CalendarEvent, int> colOf = {};
    for (final e in visible) {
      int placed = -1;
      for (int c = 0; c < columns.length; c++) {
        if (!columns[c].any((other) => _overlap(e, other))) {
          columns[c].add(e);
          placed = c;
          break;
        }
      }
      if (placed == -1) {
        columns.add([e]);
        placed = columns.length - 1;
      }
      colOf[e] = placed;
    }
    final totalCols = columns.length;

    // 3) Cada evento se expande hacia la derecha mientras las columnas
    // siguientes no tengan nada que se le solape en el tiempo. Esto es lo
    // que hace que dos eventos que NO se solapan entre sí (aunque ambos
    // toquen a un tercero) no dejen un hueco vacío al lado.
    for (final e in visible) {
      final c = colOf[e]!;
      int span = 1;
      for (int nc = c + 1; nc < totalCols; nc++) {
        final blocked = columns[nc].any((other) => _overlap(e, other));
        if (blocked) break;
        span++;
      }
      result.add(PositionedEvent(
        event: e,
        column: c,
        columnSpan: span,
        columnCount: totalCols,
        hiddenCount: (e == visible.last) ? hidden : 0,
      ));
    }

    i = j;
  }
  return result;
}