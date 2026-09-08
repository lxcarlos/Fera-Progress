import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alto mínimo, máximo y por defecto de una hora en la cuadrícula del
/// calendario. Se usan tanto en la vista de Día como en la de Semana.
const double kMinHourHeight = 28.0;
const double kMaxHourHeight = 160.0;
const double kDefaultHourHeight = 60.0;

/// Controlador global (singleton) del nivel de zoom y posición de scroll del calendario.
///
/// Al ser compartido entre DayAgenda y WeekView y guardarse en preferencias, el
/// zoom y la posición vertical de la hora se mantienen exactamente iguales sin
/// importar si cambias de día, de semana, o si alternas entre vistas.
class CalendarZoom {
  CalendarZoom._();

  static const String _prefKey = 'calendar_zoom_hour_height';
  static final ValueNotifier<double> hourHeight =
      ValueNotifier<double>(kDefaultHourHeight);

  /// Recuerda la posición vertical del scroll para que no vuelva arriba
  /// ni brinque bruscamente al cambiar de día o semana.
  static double lastScrollOffset = -1.0;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefKey);
    if (saved != null) {
      hourHeight.value = saved.clamp(kMinHourHeight, kMaxHourHeight);
    }
  }

  static void setHeight(double value) {
    final clamped = value.clamp(kMinHourHeight, kMaxHourHeight);
    hourHeight.value = clamped;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_prefKey, clamped);
    });
  }

  static void updateScrollOffset(double offset) {
    if (offset >= 0) {
      lastScrollOffset = offset;
    }
  }
}