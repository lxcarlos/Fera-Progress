import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio centralizado de respuesta háptica y vibración de la app.
/// Permite activar o desactivar la respuesta táctil desde Configuración.
class AppHaptics {
  AppHaptics._();

  static const String _prefKey = 'haptics_enabled';
  static bool _enabled = true;

  static bool get isEnabled => _enabled;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    if (enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void selectionClick() {
    if (_enabled) {
      HapticFeedback.selectionClick();
    }
  }

  static void lightImpact() {
    if (_enabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void mediumImpact() {
    if (_enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void heavyImpact() {
    if (_enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  static void vibrate() {
    if (_enabled) {
      HapticFeedback.vibrate();
    }
  }
}
