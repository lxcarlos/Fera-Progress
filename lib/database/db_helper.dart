import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../models/calendar_event.dart';
import '../utils/recurrence_utils.dart';
import '../utils/app_events.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'feraprogress.db');
    return await openDatabase(path, version: 8, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL,
        timeLimit TEXT,
        dueDate TEXT,
        description TEXT,
        isPaused INTEGER NOT NULL DEFAULT 0,
        isTask INTEGER NOT NULL DEFAULT 0,
        points INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'general',
        currentStreak INTEGER NOT NULL DEFAULT 0,
        bestStreak INTEGER NOT NULL DEFAULT 0,
        color TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL,
        completedAt TEXT,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE extra_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        points INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'general',
        date TEXT NOT NULL,
        color TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE calendar_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        startTime TEXT NOT NULL,
        endTime TEXT,
        date TEXT NOT NULL,
        recurrence TEXT NOT NULL DEFAULT 'none',
        weekdays TEXT,
        repeatUntil TEXT,
        category TEXT NOT NULL DEFAULT 'general',
        createdAt TEXT NOT NULL,
        color TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE event_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (eventId) REFERENCES calendar_events (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE event_exceptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (eventId) REFERENCES calendar_events (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE event_habit_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        habitId INTEGER NOT NULL,
        FOREIGN KEY (eventId) REFERENCES calendar_events (id) ON DELETE CASCADE,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE habits ADD COLUMN category TEXT NOT NULL DEFAULT 'general'");
      await db.execute("ALTER TABLE habits ADD COLUMN currentStreak INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE habits ADD COLUMN bestStreak INTEGER NOT NULL DEFAULT 0");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE extra_activities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT NOT NULL,
          points INTEGER NOT NULL,
          category TEXT NOT NULL DEFAULT 'general',
          date TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE habits ADD COLUMN dueDate TEXT");
      await db.execute("ALTER TABLE habits ADD COLUMN description TEXT");
      await db.execute("ALTER TABLE habit_records ADD COLUMN completedAt TEXT");
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE habits ADD COLUMN isTask INTEGER NOT NULL DEFAULT 0");
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE calendar_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          startTime TEXT NOT NULL,
          endTime TEXT,
          date TEXT NOT NULL,
          recurrence TEXT NOT NULL DEFAULT 'none',
          category TEXT NOT NULL DEFAULT 'general',
          linkedHabitId INTEGER,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE event_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eventId INTEGER NOT NULL,
          date TEXT NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (eventId) REFERENCES calendar_events (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 8) {
      await db.execute("ALTER TABLE habits ADD COLUMN color TEXT");
      await db.execute("ALTER TABLE calendar_events ADD COLUMN color TEXT");
      await db.execute("ALTER TABLE extra_activities ADD COLUMN color TEXT");
    }
    

    if (oldVersion < 7) {
      // Nuevas columnas para repetición semanal por día y fecha límite.
      await db.execute("ALTER TABLE calendar_events ADD COLUMN weekdays TEXT");
      await db.execute("ALTER TABLE calendar_events ADD COLUMN repeatUntil TEXT");

      await db.execute('''
        CREATE TABLE IF NOT EXISTS event_exceptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eventId INTEGER NOT NULL,
          date TEXT NOT NULL,
          FOREIGN KEY (eventId) REFERENCES calendar_events (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS event_habit_links (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eventId INTEGER NOT NULL,
          habitId INTEGER NOT NULL,
          FOREIGN KEY (eventId) REFERENCES calendar_events (id) ON DELETE CASCADE,
          FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
        )
      ''');

      // Migrar eventos existentes al nuevo esquema de recurrencia:
      // 'daily' -> semanal con los 7 días marcados (mismo comportamiento).
      // 'weekly' -> semanal con solo el día original marcado.
      // 'monthly' (ya no existe en la app) -> se conserva como fecha única.
      final existingEvents = await db.query('calendar_events');
      for (final e in existingEvents) {
        final id = e['id'] as int;
        final oldRecurrence = e['recurrence'] as String? ?? 'none';
        final anchor = DateTime.parse(e['date'] as String);

        String newRecurrence = 'none';
        String? weekdaysCsv;
        if (oldRecurrence == 'daily') {
          newRecurrence = 'weekly';
          weekdaysCsv = '1,2,3,4,5,6,7';
        } else if (oldRecurrence == 'weekly') {
          newRecurrence = 'weekly';
          weekdaysCsv = '${anchor.weekday}';
        }

        await db.update(
          'calendar_events',
          {'recurrence': newRecurrence, 'weekdays': weekdaysCsv},
          where: 'id = ?',
          whereArgs: [id],
        );

        // linkedHabitId (columna vieja, si existía) -> event_habit_links.
        if (e.containsKey('linkedHabitId') && e['linkedHabitId'] != null) {
          await db.insert('event_habit_links', {'eventId': id, 'habitId': e['linkedHabitId']});
        }
      }
    }
  }

  // ---- Hábitos ----

  Future<int> createHabit(Habit habit) async {
    final db = await database;
    final id = await db.insert('habits', habit.toMap());
    AppEvents.notifyDataChanged();
    return id;
  }

  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final result = await db.query('habits', orderBy: 'createdAt DESC');
    return result.map((map) => Habit.fromMap(map)).toList();
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await database;
    final res = await db.update('habits', habit.toMap(), where: 'id = ?', whereArgs: [habit.id]);
    AppEvents.notifyDataChanged();
    return res;
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    final res = await db.delete('habits', where: 'id = ?', whereArgs: [id]);
    AppEvents.notifyDataChanged();
    return res;
  }

  Future<void> markHabitCompletion(int habitId, DateTime date, bool completed) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final existing = await db.query('habit_records', where: 'habitId = ? AND date = ?', whereArgs: [habitId, dateStr]);

    if (existing.isNotEmpty) {
      await db.update(
        'habit_records',
        {'completed': completed ? 1 : 0, 'completedAt': completed ? DateTime.now().toIso8601String() : null},
        where: 'habitId = ? AND date = ?',
        whereArgs: [habitId, dateStr],
      );
    } else {
      await db.insert('habit_records', {
        'habitId': habitId,
        'date': dateStr,
        'completed': completed ? 1 : 0,
        'completedAt': completed ? DateTime.now().toIso8601String() : null,
      });
    }
    AppEvents.notifyDataChanged();
  }

  Future<void> unmarkHabitCompletion(int habitId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    await db.update(
      'habit_records',
      {'completed': 0, 'completedAt': null},
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, dateStr],
    );
    AppEvents.notifyDataChanged();
  }

  Future<bool> wasCompletedOn(int habitId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final result = await db.query('habit_records', where: 'habitId = ? AND date = ? AND completed = 1', whereArgs: [habitId, dateStr]);
    return result.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getRecordForDate(int habitId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final result = await db.query('habit_records', where: 'habitId = ? AND date = ?', whereArgs: [habitId, dateStr]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getRecordsForHabit(int habitId) async {
    final db = await database;
    return await db.query('habit_records', where: 'habitId = ?', whereArgs: [habitId], orderBy: 'date DESC');
  }

  
  Future<Set<String>> getCompletedDates() async {
    final db = await database;
    final result = await db.query('habit_records', where: 'completed = 1', columns: ['date']);
    return result.map((r) => r['date'] as String).toSet();
  }

  /// Cuántos hábitos se completaron cada día de un año dado. Es la base
  /// del heatmap estilo GitHub: cada día es un cuadrito, y entre más
  /// hábitos completados ese día, más oscuro/intenso se pinta.
  Future<Map<String, int>> getCompletionCountsByYear(int year) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT date, COUNT(*) as cnt FROM habit_records WHERE completed = 1 AND date LIKE ? GROUP BY date",
      ['$year-%'],
    );
    return {for (final r in result) r['date'] as String: r['cnt'] as int};
  }
  

  Future<Set<String>> getCompletedDatesForHabit(int habitId) async {
    final db = await database;
    final result = await db.query('habit_records', where: 'habitId = ? AND completed = 1', whereArgs: [habitId], columns: ['date']);
    return result.map((r) => r['date'] as String).toSet();
  }

  Future<DateTime?> getEarliestHabitDate() async {
    final db = await database;
    final result = await db.query('habits', orderBy: 'createdAt ASC', limit: 1);
    if (result.isEmpty) return null;
    return DateTime.parse(result.first['createdAt'] as String);
  }

  Future<void> processMissedDays() async {
    final db = await database;
    final habits = await getAllHabits();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final habit in habits) {
      if (habit.isPaused || habit.isTask || habit.id == null) continue;

      DateTime cursor = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
      final earliestCheck = today.subtract(const Duration(days: 30));
      if (cursor.isBefore(earliestCheck)) cursor = earliestCheck;

      while (cursor.isBefore(today)) {
        final dateStr = cursor.toIso8601String().split('T')[0];
        final existing = await db.query('habit_records', where: 'habitId = ? AND date = ?', whereArgs: [habit.id, dateStr]);

        if (existing.isEmpty) {
          await db.insert('habit_records', {'habitId': habit.id, 'date': dateStr, 'completed': 0, 'completedAt': null});

          final freshHabit = await db.query('habits', where: 'id = ?', whereArgs: [habit.id]);
          if (freshHabit.isNotEmpty) {
            final currentPoints = freshHabit.first['points'] as int;
            final newPoints = (currentPoints - 1) < 0 ? 0 : currentPoints - 1;
            await db.update('habits', {'points': newPoints, 'currentStreak': 0}, where: 'id = ?', whereArgs: [habit.id]);
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
  }

  Future<void> cleanupExpired() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final extras = await db.query('extra_activities');
    int pointsToBank = 0;
    final List<int> extraIdsToDelete = [];
    for (final e in extras) {
      final d = DateTime.parse(e['date'] as String);
      final dDay = DateTime(d.year, d.month, d.day);
      if (dDay.isBefore(today)) {
        pointsToBank += (e['points'] as int);
        extraIdsToDelete.add(e['id'] as int);
      }
    }
    if (extraIdsToDelete.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final currentBank = prefs.getInt('banked_extra_points') ?? 0;
      await prefs.setInt('banked_extra_points', currentBank + pointsToBank);
      await db.delete('extra_activities', where: 'id IN (${extraIdsToDelete.join(',')})');
    }

    final tasks = await db.query('habits', where: 'isTask = 1');
    for (final t in tasks) {
      DateTime expiry;
      if (t['dueDate'] != null) {
        final due = DateTime.parse(t['dueDate'] as String);
        expiry = DateTime(due.year, due.month, due.day, 23, 59, 59);
      } else {
        final created = DateTime.parse(t['createdAt'] as String);
        expiry = DateTime(created.year, created.month, created.day, 23, 59, 59);
      }
      if (now.isAfter(expiry)) {
        await db.delete('habits', where: 'id = ?', whereArgs: [t['id']]);
      }
    }
  }

  Future<Map<String, int>> getPointsByCategory() async {
    final db = await database;
    final habitResult = await db.rawQuery('SELECT category, SUM(points) as total FROM habits WHERE isTask = 0 GROUP BY category');
    final extraResult = await db.rawQuery('SELECT category, SUM(points) as total FROM extra_activities GROUP BY category');

    final Map<String, int> map = {};
    for (final row in habitResult) {
      final cat = row['category'] as String;
      map[cat] = (map[cat] ?? 0) + ((row['total'] as int?) ?? 0);
    }
    for (final row in extraResult) {
      final cat = row['category'] as String;
      map[cat] = (map[cat] ?? 0) + ((row['total'] as int?) ?? 0);
    }
    return map;
  }

  Future<int> getMaxStreak() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(bestStreak) as maxStreak FROM habits');
    return (result.first['maxStreak'] as int?) ?? 0;
  }

  Future<int> getTotalCompletions() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM habit_records WHERE completed = 1');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> createExtraActivity({required String description, required int points, required String category, String? color}) async {
    final db = await database;
    final id = await db.insert('extra_activities', {
      'description': description,
      'points': points,
      'category': category,
      'date': DateTime.now().toIso8601String(),
      'color': color,
    });
    AppEvents.notifyDataChanged();
    return id;
  }

  Future<List<Map<String, dynamic>>> getRecentExtraActivities({int limit = 10}) async {
    final db = await database;
    return await db.query('extra_activities', orderBy: 'date DESC', limit: limit);
  }

  Future<int> deleteExtraActivity(int id) async {
    final db = await database;
    final res = await db.delete('extra_activities', where: 'id = ?', whereArgs: [id]);
    AppEvents.notifyDataChanged();
    return res;
  }

  Future<int> getExtraActivitiesTotalPoints() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(points) as total FROM extra_activities');
    final activePoints = (result.first['total'] as int?) ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final banked = prefs.getInt('banked_extra_points') ?? 0;
    return activePoints + banked;
  }

  Future<List<Map<String, dynamic>>> getHabitsStatusForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final habits = await db.query('habits');

    List<Map<String, dynamic>> result = [];
    for (final h in habits) {
      final createdAt = DateTime.parse(h['createdAt'] as String);
      if (createdAt.isAfter(date)) continue;
      final record = await db.query('habit_records', where: 'habitId = ? AND date = ?', whereArgs: [h['id'], dateStr]);
      result.add({
        'id': h['id'],
        'name': h['name'],
        'category': h['category'],
        'isTask': h['isTask'] == 1,
        'completed': record.isNotEmpty && record.first['completed'] == 1,
      });
    }
    return result;
  }

  Future<Map<String, int>> getDayStats(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    final habits = await db.query('habits', where: 'isTask = 0');

    int total = 0;
    int completed = 0;
    final targetDay = DateTime(date.year, date.month, date.day);

    for (final h in habits) {
      final createdAt = DateTime.parse(h['createdAt'] as String);
      final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (createdDay.isAfter(targetDay)) continue;
      total++;
      final record = await db.query('habit_records', where: 'habitId = ? AND date = ?', whereArgs: [h['id'], dateStr]);
      if (record.isNotEmpty && record.first['completed'] == 1) completed++;
    }

    return {'completed': completed, 'total': total};
  }

  /// Aplica los mismos efectos (puntos/racha) que marcar un hábito desde Hábitos,
  /// pero de forma directa en la base de datos (usado por eventos vinculados).
  Future<void> setHabitCompletionWithEffects(int habitId, DateTime date, bool completed) async {
    final db = await database;
    final rows = await db.query('habits', where: 'id = ?', whereArgs: [habitId]);
    if (rows.isEmpty) return;
    final habit = Habit.fromMap(rows.first);
    if (habit.isPaused) return;

    final isCurrentlyCompleted = await wasCompletedOn(habitId, date);
    if (completed == isCurrentlyCompleted) return;

    if (completed) {
      await markHabitCompletion(habitId, date, true);
      if (!habit.isTask) {
        final yesterday = date.subtract(const Duration(days: 1));
        final wasYesterday = await wasCompletedOn(habitId, yesterday);
        final newStreak = wasYesterday ? habit.currentStreak + 1 : 1;
        final newBest = newStreak > habit.bestStreak ? newStreak : habit.bestStreak;
        await db.update('habits', {'points': habit.points + 1, 'currentStreak': newStreak, 'bestStreak': newBest}, where: 'id = ?', whereArgs: [habitId]);
      }
    } else {
      await unmarkHabitCompletion(habitId, date);
      if (!habit.isTask) {
        final newPoints = (habit.points - 1) < 0 ? 0 : habit.points - 1;
        final newStreak = (habit.currentStreak - 1) < 0 ? 0 : habit.currentStreak - 1;
        await db.update('habits', {'points': newPoints, 'currentStreak': newStreak}, where: 'id = ?', whereArgs: [habitId]);
      }
    }
    AppEvents.notifyDataChanged();
  }

  // ---- Eventos del calendario ----

  Future<int> createEvent(CalendarEvent event, {List<int> linkedHabitIds = const []}) async {
    final db = await database;
    final id = await db.insert('calendar_events', event.toMap());
    for (final habitId in linkedHabitIds) {
      await db.insert('event_habit_links', {'eventId': id, 'habitId': habitId});
    }
    AppEvents.notifyDataChanged();
    return id;
  }

  Future<int> updateEvent(CalendarEvent event, {List<int>? linkedHabitIds}) async {
    final db = await database;
    final res = await db.update('calendar_events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
    if (linkedHabitIds != null && event.id != null) {
      await db.delete('event_habit_links', where: 'eventId = ?', whereArgs: [event.id]);
      for (final habitId in linkedHabitIds) {
        await db.insert('event_habit_links', {'eventId': event.id, 'habitId': habitId});
      }
    }
    AppEvents.notifyDataChanged();
    return res;
  }

  /// Elimina el evento completo (todas sus ocurrencias, pasadas y futuras).
  Future<void> deleteEventAll(int id) async {
    final db = await database;
    await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
    AppEvents.notifyDataChanged();
  }

  /// Elimina solo la ocurrencia de [date], sin afectar las demás fechas de
  /// un evento repetido (agrega una excepción). Si el evento no se repite,
  /// se elimina por completo.
  Future<void> deleteEventOccurrence(CalendarEvent event, DateTime date) async {
    final db = await database;
    if (event.id == null) return;
    if (!event.isRecurring) {
      await db.delete('calendar_events', where: 'id = ?', whereArgs: [event.id]);
    } else {
      final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
      await db.insert('event_exceptions', {'eventId': event.id, 'date': dateStr});
    }
    AppEvents.notifyDataChanged();
  }

  /// Elimina esta ocurrencia y todas las siguientes, conservando las
  /// ocurrencias anteriores a [date] intactas.
  Future<void> deleteEventFromDateOnward(CalendarEvent event, DateTime date) async {
    final db = await database;
    if (event.id == null) return;
    final anchor = DateTime(event.date.year, event.date.month, event.date.day);
    final target = DateTime(date.year, date.month, date.day);

    if (!event.isRecurring || !target.isAfter(anchor)) {
      // No hay ocurrencias anteriores que conservar: se elimina todo.
      await db.delete('calendar_events', where: 'id = ?', whereArgs: [event.id]);
    } else {
      final dayBefore = target.subtract(const Duration(days: 1));
      final updated = event.copyWith(repeatUntil: dayBefore);
      await db.update('calendar_events', updated.toMap(), where: 'id = ?', whereArgs: [event.id]);
    }
    AppEvents.notifyDataChanged();
  }

  /// Actualiza SOLO la ocurrencia de [occurrenceDate] de un evento repetido:
  /// agrega una excepción en la fecha original (para que ese día ya no
  /// muestre la versión vieja) y crea un evento nuevo e independiente, sin
  /// repetición, con los datos editados. Si el evento no se repite, esto
  /// equivale a un update normal.
  Future<void> updateEventOccurrence(
    CalendarEvent original,
    CalendarEvent updated,
    DateTime occurrenceDate, {
    List<int>? linkedHabitIds,
  }) async {
    if (!original.isRecurring || original.id == null) {
      await updateEvent(updated, linkedHabitIds: linkedHabitIds);
      return;
    }
    final db = await database;
    final dateStr = DateTime(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day).toIso8601String().split('T')[0];
    await db.insert('event_exceptions', {'eventId': original.id, 'date': dateStr});

    final oneOff = CalendarEvent(
      title: updated.title,
      description: updated.description,
      startTime: updated.startTime,
      endTime: updated.endTime,
      date: occurrenceDate,
      recurrence: 'none',
      weekdays: const [],
      repeatUntil: null,
      category: updated.category,
      createdAt: DateTime.now(),
    );
    final links = linkedHabitIds ?? await getLinkedHabitIds(original.id!);
    await createEvent(oneOff, linkedHabitIds: links);
    AppEvents.notifyDataChanged();
  }

  /// Actualiza esta ocurrencia y todas las que siguen de un evento
  /// repetido, dejando intactas las anteriores a [occurrenceDate]: corta
  /// la serie original justo antes de esa fecha y crea una serie nueva a
  /// partir de ahí con los datos editados.
  Future<void> updateEventFromDateOnward(
    CalendarEvent original,
    CalendarEvent updated,
    DateTime occurrenceDate, {
    List<int>? linkedHabitIds,
  }) async {
    final db = await database;
    if (original.id == null) return;
    final anchor = DateTime(original.date.year, original.date.month, original.date.day);
    final target = DateTime(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day);

    if (!original.isRecurring || !target.isAfter(anchor)) {
      // No hay ocurrencias anteriores que conservar: se reemplaza todo el evento.
      await updateEvent(updated.copyWith(date: original.date), linkedHabitIds: linkedHabitIds);
      return;
    }

    final dayBefore = target.subtract(const Duration(days: 1));
    final cappedOriginal = original.copyWith(repeatUntil: dayBefore);
    await db.update('calendar_events', cappedOriginal.toMap(), where: 'id = ?', whereArgs: [original.id]);

    final newSeries = CalendarEvent(
      title: updated.title,
      description: updated.description,
      startTime: updated.startTime,
      endTime: updated.endTime,
      date: occurrenceDate,
      recurrence: updated.recurrence,
      weekdays: updated.weekdays,
      repeatUntil: updated.repeatUntil,
      category: updated.category,
      createdAt: DateTime.now(),
    );
    final links = linkedHabitIds ?? await getLinkedHabitIds(original.id!);
    await createEvent(newSeries, linkedHabitIds: links);
    AppEvents.notifyDataChanged();
  }

  /// Mueve SOLO la ocurrencia de [date] de un evento a un nuevo horario
  /// (se usa al arrastrar un evento en Día/Semana). Igual que al editar
  /// "solo este", si el evento se repite se crea una excepción en la
  /// fecha vieja y un evento suelto en el nuevo horario; si no se repite,
  /// se mueve el evento tal cual.
  Future<void> moveEventOccurrence(CalendarEvent event, DateTime date, String newStartTime, String newEndTime) async {
    if (event.id == null) return;
    if (!event.isRecurring) {
      final updated = event.copyWith(startTime: newStartTime, endTime: newEndTime);
      await updateEvent(updated);
      return;
    }
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    await db.insert('event_exceptions', {'eventId': event.id, 'date': dateStr});

    final moved = CalendarEvent(
      title: event.title,
      description: event.description,
      startTime: newStartTime,
      endTime: newEndTime,
      date: date,
      recurrence: 'none',
      weekdays: const [],
      repeatUntil: null,
      category: event.category,
      createdAt: DateTime.now(),
    );
    final links = await getLinkedHabitIds(event.id!);
    await createEvent(moved, linkedHabitIds: links);
    AppEvents.notifyDataChanged();
  }

  /// Cuenta cuántos eventos de [date] se solapan en el tiempo con el rango
  /// [startTime]-[endTime] (sin contar al propio evento si se está
  /// editando uno existente). Se usa para avisar cuando ya hay 3 eventos
  /// encimados y no cabe un cuarto en la cuadrícula de Día/Semana.
  Future<int> countOverlappingEvents(
    DateTime date,
    String startTime,
    String endTime, {
    int? excludeEventId,
  }) async {
    final events = await getEventsForDate(date);
    int toMinutes(String hhmm) {
      final p = hhmm.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final s1 = toMinutes(startTime);
    final e1 = toMinutes(endTime);
    int count = 0;
    for (final e in events) {
      if (excludeEventId != null && e.id == excludeEventId) continue;
      final s2 = toMinutes(e.startTime);
      final e2 = e.endTime != null ? toMinutes(e.endTime!) : s2 + 30;
      if (s1 < e2 && s2 < e1) count++;
    }
    return count;
  }

  Future<List<CalendarEvent>> getAllEvents() async {
    final db = await database;
    final result = await db.query('calendar_events');
    return result.map((m) => CalendarEvent.fromMap(m)).toList();
  }

  Future<List<int>> getLinkedHabitIds(int eventId) async {
    final db = await database;
    final rows = await db.query('event_habit_links', where: 'eventId = ?', whereArgs: [eventId]);
    return rows.map((r) => r['habitId'] as int).toList();
  }

  Future<Set<String>> _getExceptionDates(int eventId) async {
    final db = await database;
    final rows = await db.query('event_exceptions', where: 'eventId = ?', whereArgs: [eventId], columns: ['date']);
    return rows.map((r) => r['date'] as String).toSet();
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final db = await database;
    final rawEvents = await db.query('calendar_events');

    final List<CalendarEvent> result = [];
    for (final map in rawEvents) {
      var event = CalendarEvent.fromMap(map);
      final exceptionDates = event.isRecurring ? await _getExceptionDates(event.id!) : const <String>{};
      if (!eventOccursOnDate(event, date, exceptionDates: exceptionDates)) continue;

      final links = await getLinkedHabitIds(event.id!);
      event = event.copyWith(linkedHabitIds: links);
      result.add(event);
    }
    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  Future<bool> getEventCompletion(int eventId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final result = await db.query('event_records', where: 'eventId = ? AND date = ?', whereArgs: [eventId, dateStr]);
    return result.isNotEmpty && result.first['completed'] == 1;
  }

  Future<void> setEventCompletion(int eventId, DateTime date, bool completed) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final existing = await db.query('event_records', where: 'eventId = ? AND date = ?', whereArgs: [eventId, dateStr]);
    if (existing.isNotEmpty) {
      await db.update('event_records', {'completed': completed ? 1 : 0}, where: 'eventId = ? AND date = ?', whereArgs: [eventId, dateStr]);
    } else {
      await db.insert('event_records', {'eventId': eventId, 'date': dateStr, 'completed': completed ? 1 : 0});
    }
    AppEvents.notifyDataChanged();
  }

  /// Marca/desmarca un evento Y, en el mismo momento, aplica el efecto a
  /// TODOS los hábitos/tareas vinculados a él (puede ser uno o varios).
  /// Un único punto de entrada para que Día, Semana y cualquier otra
  /// pantalla queden sincronizados al instante.
  Future<void> toggleEventCompletion(int eventId, DateTime date, {required bool completed}) async {
    await setEventCompletion(eventId, date, completed);
    final linkedIds = await getLinkedHabitIds(eventId);
    for (final habitId in linkedIds) {
      await setHabitCompletionWithEffects(habitId, date, completed);
    }
    AppEvents.notifyDataChanged();
  }
}