import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../database/db_helper.dart';
import '../models/habit.dart';
import '../models/calendar_event.dart';

/// Minutos antes del límite que el usuario puede elegir en Ajustes.
/// -1 significa "desactivadas".
const List<int> kNotificationOffsetOptions = [-1, 0, 5, 10, 15, 30];

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _prefKeyMinutesBefore = 'notif_minutes_before';

  void _configureLocalTimeZone() {
    tz_data.initializeTimeZones();
    final now = DateTime.now();
    final offsetMs = now.timeZoneOffset.inMilliseconds;

    final sysName = now.timeZoneName.trim();
    if (sysName.contains('/')) {
      try {
        tz.setLocalLocation(tz.getLocation(sysName));
        return;
      } catch (_) {}
    }

    final preferredByOffset = <int, List<String>>{
      -21600000: ['America/Mexico_City', 'America/Guatemala', 'America/Costa_Rica'], // UTC-6
      -18000000: ['America/Bogota', 'America/Lima', 'America/New_York', 'America/Panama'], // UTC-5
      -14400000: ['America/Caracas', 'America/Santiago', 'America/La_Paz'], // UTC-4
      -10800000: ['America/Argentina/Buenos_Aires', 'America/Montevideo', 'America/Sao_Paulo'], // UTC-3
      0: ['UTC', 'Europe/London'],
      3600000: ['Europe/Madrid', 'Europe/Paris'], // UTC+1
      7200000: ['Europe/Madrid', 'Europe/Athens'], // UTC+2
      -25200000: ['America/Hermosillo', 'America/Mazatlan', 'America/Denver'], // UTC-7
      -28800000: ['America/Tijuana', 'America/Los_Angeles'], // UTC-8
    };

    final preferred = preferredByOffset[offsetMs];
    if (preferred != null) {
      for (final name in preferred) {
        try {
          tz.setLocalLocation(tz.getLocation(name));
          return;
        } catch (_) {}
      }
    }

    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == offsetMs) {
        tz.setLocalLocation(loc);
        return;
      }
    }
  }

  void _ensureTimeZone() {
    final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    if (tz.local.name == 'UTC' && offsetMs != 0) {
      _configureLocalTimeZone();
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;

    // Reprogramar con la zona horaria local correcta y limpiar notificaciones desfasadas
    await rescheduleAll();
  }

  /// Minutos antes del límite en que avisa. -1 = notificaciones apagadas.
  Future<int> getMinutesBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyMinutesBefore) ?? 15;
  }

  Future<void> setMinutesBefore(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyMinutesBefore, minutes);
    await rescheduleAll();
  }

  /// Vuelve a agendar las notificaciones de todos los hábitos, tareas y eventos
  /// con horario, usando la preferencia actual de minutos antes y la zona horaria del dispositivo.
  Future<void> rescheduleAll() async {
    _ensureTimeZone();
    await _plugin.cancelAll();

    final habits = await DBHelper().getAllHabits();
    for (final habit in habits) {
      if (habit.isTask) {
        await scheduleForTask(habit);
      } else {
        await scheduleForHabit(habit);
      }
    }

    final events = await DBHelper().getAllEvents();
    for (final event in events) {
      await scheduleForEvent(event);
    }
  }

  // ---- IDs no colisionables ----
  int _habitIdFor(int id) => 100000 + id;
  int _taskIdFor(int id) => 200000 + id;
  int _eventIdFor(int id) => 300000 + id;
  int _recurringEventIdFor(int id, int weekday) => 300000 + (id * 10) + weekday;

  // ==============================
  // 1. HÁBITOS
  // ==============================
  Future<void> scheduleForHabit(Habit habit) async {
    if (habit.id == null) return;
    _ensureTimeZone();

    final minutesBefore = await getMinutesBefore();
    if (habit.timeLimit == null || habit.isPaused || habit.isTask || minutesBefore < 0) {
      await cancelForHabit(habit.id);
      return;
    }

    final parts = habit.timeLimit!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
        .subtract(Duration(minutes: minutesBefore));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final title = '🔥 Hábito: ${habit.name}';
    final body = minutesBefore == 0
        ? 'Hora de cumplir: "${habit.name}"'
        : 'Faltan $minutesBefore min para tu hábito (${habit.timeLimit})';

    await _plugin.zonedSchedule(
      _habitIdFor(habit.id!),
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Recordatorios de hábitos',
          channelDescription: 'Avisa cuando se acerca el horario de un hábito',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFFFF8A00),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelForHabit(int? habitId) async {
    if (habitId == null) return;
    await _plugin.cancel(_habitIdFor(habitId));
  }

  // ==============================
  // 2. TAREAS DEL DÍA
  // ==============================
  Future<void> scheduleForTask(Habit task) async {
    if (task.id == null || !task.isTask) return;
    _ensureTimeZone();

    final minutesBefore = await getMinutesBefore();
    if (minutesBefore < 0) {
      await cancelForTask(task.id);
      return;
    }

    final targetDate = task.dueDate ?? task.createdAt;
    int hour = 20;
    int minute = 0;
    if (task.timeLimit != null) {
      final parts = task.timeLimit!.split(':');
      hour = int.parse(parts[0]);
      minute = int.parse(parts[1]);
    }

    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, hour, minute)
        .subtract(Duration(minutes: minutesBefore));

    if (scheduled.isBefore(now)) {
      await cancelForTask(task.id);
      return;
    }

    final title = '✅ Tarea: ${task.name}';
    final body = minutesBefore == 0
        ? 'Es momento de tu tarea: "${task.name}"'
        : 'Tu tarea "${task.name}" vence en $minutesBefore min';

    await _plugin.zonedSchedule(
      _taskIdFor(task.id!),
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Recordatorios de tareas',
          channelDescription: 'Avisa sobre tareas del día pendientes',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF3B82F6),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelForTask(int? taskId) async {
    if (taskId == null) return;
    await _plugin.cancel(_taskIdFor(taskId));
  }

  // ==============================
  // 3. EVENTOS DEL CALENDARIO
  // ==============================
  Future<void> scheduleForEvent(CalendarEvent event) async {
    if (event.id == null) return;
    _ensureTimeZone();

    final minutesBefore = await getMinutesBefore();
    if (minutesBefore < 0) {
      await cancelForEvent(event.id);
      return;
    }

    final parts = event.startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = tz.TZDateTime.now(tz.local);

    const androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Recordatorios de eventos',
      channelDescription: 'Avisos de eventos agendados en tu calendario',
      importance: Importance.max,
      priority: Priority.max,
      color: Color(0xFF10B981),
    );
    const notifDetails = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final title = '📅 Evento: ${event.title}';

    if (!event.isRecurring) {
      final eventDate = event.date;
      final scheduled = tz.TZDateTime(tz.local, eventDate.year, eventDate.month, eventDate.day, hour, minute)
          .subtract(Duration(minutes: minutesBefore));

      if (scheduled.isAfter(now)) {
        final body = minutesBefore == 0
            ? 'Comienza ahora (${event.startTime})'
            : 'Comienza en $minutesBefore min (${event.startTime})';

        await _plugin.zonedSchedule(
          _eventIdFor(event.id!),
          title,
          body,
          scheduled,
          notifDetails,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } else {
        await _plugin.cancel(_eventIdFor(event.id!));
      }
    } else {
      // Evento semanal recurrente
      for (final weekday in event.weekdays) {
        var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
            .subtract(Duration(minutes: minutesBefore));
        while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        if (event.repeatUntil != null && scheduled.isAfter(event.repeatUntil!)) {
          continue;
        }

        final body = minutesBefore == 0
            ? 'Comienza ahora (${event.startTime})'
            : 'Comienza en $minutesBefore min (${event.startTime})';

        await _plugin.zonedSchedule(
          _recurringEventIdFor(event.id!, weekday),
          title,
          body,
          scheduled,
          notifDetails,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  Future<void> cancelForEvent(int? eventId) async {
    if (eventId == null) return;
    await _plugin.cancel(_eventIdFor(eventId));
    for (int w = 1; w <= 7; w++) {
      await _plugin.cancel(_recurringEventIdFor(eventId, w));
    }
  }
}