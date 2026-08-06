import '../models/calendar_event.dart';

/// Indica si [event] tiene una ocurrencia en [date].
///
/// [exceptionDates] son fechas (formato "yyyy-MM-dd") en las que esa
/// ocurrencia puntual fue eliminada con "Eliminar solo este evento",
/// aunque el evento siga repitiéndose en las demás fechas.
bool eventOccursOnDate(
  CalendarEvent event,
  DateTime date, {
  Set<String> exceptionDates = const {},
}) {
  final anchor = DateTime(event.date.year, event.date.month, event.date.day);
  final target = DateTime(date.year, date.month, date.day);
  if (target.isBefore(anchor)) return false;

  if (exceptionDates.isNotEmpty) {
    final key = '${target.year.toString().padLeft(4, '0')}-'
        '${target.month.toString().padLeft(2, '0')}-'
        '${target.day.toString().padLeft(2, '0')}';
    if (exceptionDates.contains(key)) return false;
  }

  if (event.recurrence == 'weekly' && event.weekdays.isNotEmpty) {
    if (event.repeatUntil != null) {
      final until = DateTime(event.repeatUntil!.year, event.repeatUntil!.month, event.repeatUntil!.day);
      if (target.isAfter(until)) return false;
    }
    return event.weekdays.contains(target.weekday);
  }

  // 'none' (o cualquier valor heredado que ya no se usa, ej. 'daily'/'monthly'
  // de versiones anteriores): solo ocurre en su fecha ancla.
  return anchor.year == target.year && anchor.month == target.month && anchor.day == target.day;
}