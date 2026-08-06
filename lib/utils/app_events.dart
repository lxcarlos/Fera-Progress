import 'package:flutter/foundation.dart';

/// Notificador global: cada vez que algo cambia en la base de datos
/// (se completa un hábito, una tarea, un evento, se crea/edita/elimina
/// algo), se llama a [AppEvents.notifyDataChanged]. Hábitos, Calendario
/// y Perfil viven montados al mismo tiempo (ver MainNav), así que basta
/// con que cada pantalla escuche este notificador y recargue sus datos
/// para que todo se vea actualizado al instante, sin cerrar ni abrir la
/// app y sin importar en qué pestaña se hizo el cambio.
class AppEvents {
  AppEvents._();

  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    tick.value++;
  }
}