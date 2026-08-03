import '../models/calendar_event.dart';

bool eventOccursOnDate(CalendarEvent event, DateTime date) {
  final anchor = DateTime(event.date.year, event.date.month, event.date.day);
  final target = DateTime(date.year, date.month, date.day);
  if (target.isBefore(anchor)) return false;

  switch (event.recurrence) {
    case 'daily':
      return true;
    case 'weekly':
      return anchor.weekday == target.weekday;
    case 'monthly':
      return anchor.day == target.day;
    default:
      return anchor.year == target.year && anchor.month == target.month && anchor.day == target.day;
  }
}