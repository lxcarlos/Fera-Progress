import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

class StreakInfo {
  final int current;
  final int last;
  StreakInfo(this.current, this.last);
}

class StreakService {
  final DBHelper _db = DBHelper();

  Future<StreakInfo> getStreakInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Verificar primero si el día de hoy ya está 100% completado
    final todayStats = await _db.getDayStats(today);
    final todayTotal = todayStats['total'] ?? 0;
    final todayCompleted = todayStats['completed'] ?? 0;
    final todayDone = todayTotal > 0 && todayCompleted == todayTotal;

    int current = 0;
    DateTime cursor;
    if (todayDone) {
      current = 1;
      cursor = today.subtract(const Duration(days: 1));
    } else {
      // Si hoy aún está en curso, verificar si ayer sí se completó
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStats = await _db.getDayStats(yesterday);
      final yTotal = yesterdayStats['total'] ?? 0;
      final yCompleted = yesterdayStats['completed'] ?? 0;
      if (yTotal > 0 && yCompleted == yTotal) {
        current = 1;
        cursor = yesterday.subtract(const Duration(days: 1));
      } else {
        // Ni hoy ni ayer se cumplieron -> racha rota
        cursor = today;
      }
    }

    if (current > 0) {
      for (int i = 0; i < 400; i++) {
        final stats = await _db.getDayStats(cursor);
        final total = stats['total'] ?? 0;
        final completed = stats['completed'] ?? 0;
        if (total > 0 && completed == total) {
          current++;
          cursor = cursor.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    final prevCurrent = prefs.getInt('prev_current_streak') ?? 0;
    int last = prefs.getInt('last_streak_length') ?? 0;

    if (prevCurrent > 0 && current == 0) {
      last = prevCurrent;
      await prefs.setInt('last_streak_length', last);
    }
    await prefs.setInt('prev_current_streak', current);

    return StreakInfo(current, last);
  }
}