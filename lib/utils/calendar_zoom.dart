import 'package:flutter/foundation.dart';

/// Alto mínimo, máximo y por defecto de una hora en la cuadrícula del
/// calendario. Se usan tanto en la vista de Día como en la de Semana.
const double kMinHourHeight = 28.0;
const double kMaxHourHeight = 160.0;
const double kDefaultHourHeight = 60.0;

/// Controlador global (singleton) del nivel de zoom del calendario.
///
/// Al ser compartido entre DayAgenda y WeekView, el zoom se mantiene
/// exactamente igual sin importar si cambias de día, de semana, o si
/// alternas entre la vista Día y la vista Semana.
class CalendarZoom {
  CalendarZoom._();

  static final ValueNotifier<double> hourHeight =
      ValueNotifier<double>(kDefaultHourHeight);

  static void setHeight(double value) {
    hourHeight.value = value.clamp(kMinHourHeight, kMaxHourHeight);
  }
}