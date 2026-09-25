import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the explicit dark/light preference and persists the user's choice.
///
/// The first launch follows the operating-system brightness. Once a user
/// toggles the theme, that explicit choice wins on subsequent launches.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    SharedPreferences? preferences,
    Brightness? platformBrightness,
  }) : _preferences = preferences,
       _isDark = _initialDarkValue(preferences, platformBrightness);

  static const String storageKey = 'aroha_theme_is_dark';

  final SharedPreferences? _preferences;
  bool _isDark;
  Future<void> _writeQueue = Future<void>.value();

  static bool _initialDarkValue(
    SharedPreferences? preferences,
    Brightness? platformBrightness,
  ) {
    try {
      final saved = preferences?.getBool(storageKey);
      if (saved != null) return saved;
    } catch (_) {
      // A malformed/unavailable preference must not prevent app startup.
    }
    return (platformBrightness ?? Brightness.dark) == Brightness.dark;
  }

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggle() => setDark(!_isDark);

  void setDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();

    final preferences = _preferences;
    if (preferences == null) return;

    // Serialize writes so rapid toggles cannot complete out of order. The
    // catch keeps a storage failure from becoming an unhandled async error;
    // the in-memory selection remains usable for this app session.
    _writeQueue = _writeQueue.then((_) async {
      try {
        await preferences.setBool(storageKey, value);
      } catch (_) {
        // Theme selection still works in memory when persistence is offline.
      }
    });
  }
}
