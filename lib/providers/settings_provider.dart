import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _darkMode = true;
  bool _notifications = true;
  bool _autoPlay = false;

  bool get darkMode => _darkMode;
  bool get notifications => _notifications;
  bool get autoPlay => _autoPlay;

  void toggleDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
  }

  void toggleNotifications(bool value) {
    _notifications = value;
    notifyListeners();
  }

  void toggleAutoPlay(bool value) {
    _autoPlay = value;
    notifyListeners();
  }
}
