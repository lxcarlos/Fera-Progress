import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../database/db_helper.dart';
import '../models/habit.dart';

/// Minutos antes del límite que el usuario puede elegir en Ajustes.
/// -1 significa "desactivadas".
const List<int> kNotificationOffsetOptions = [-1, 0, 5, 10, 15];

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _prefKeyMinutesBefore = 'notif_minutes_before';

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  /// Minutos antes del límite en que avisa. -1 = notificaciones apagadas.
  /// Por defecto 15, para no cambiarle el comportamiento a quien ya la
  /// tenía instalada.
  Future<int> getMinutesBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyMinutesBefore) ?? 15;
  }

  Future<void> setMinutesBefore(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyMinutesBefore, minutes);
    // Al cambiar la preferencia, hay que reprogramar TODOS los hábitos que
    // ya tenían una notificación agendada con el offset viejo; si no,
    // seguirían sonando con el tiempo anterior hasta que se editara cada
    // hábito a mano.
    await rescheduleAll();
  }

  /// Vuelve a agendar las notificaciones de todos los hábitos con
  /// horario límite, usando la preferencia actual de minutos antes.
  /// Se usa al cambiar el ajuste, y también se puede llamar al abrir la
  /// app para "sanar" alarmas que el sistema haya podido perder.
  Future<void> rescheduleAll() async {
    final habits = await DBHelper().getAllHabits();
    for (final habit in habits) {
      await scheduleForHabit(habit);
    }
  }

  int _idFor(int habitId) => habitId;

  Future<void> scheduleForHabit(Habit habit) async {
    if (habit.id == null) return;

    final minutesBefore = await getMinutesBefore();
    final notificationsOff = minutesBefore < 0;

    if (habit.timeLimit == null || habit.isPaused || habit.isTask || notificationsOff) {
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

    final body = minutesBefore == 0
        ? '"${habit.name}" se cumple ahora'
        : '"${habit.name}" está por cumplirse en $minutesBefore minutos';

    await _plugin.zonedSchedule(
      _idFor(habit.id!),
      'Se acerca el límite',
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Recordatorios de hábitos',
          channelDescription: 'Avisa cuando se acerca el límite de un hábito',
          importance: Importance.high,
          priority: Priority.high,
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
    await _plugin.cancel(_idFor(habitId));
  }
}