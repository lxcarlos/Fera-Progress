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
    int current = 0;
    DateTime cursor = DateTime.now();

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