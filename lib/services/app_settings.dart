// lib/services/app_settings.dart
import 'package:flutter/material.dart';
import 'firestore_service.dart';

class AppSettings extends ChangeNotifier {
  final FirestoreService _firestoreService;

  // Einstellungen
  bool _notifications = true;
  bool _notificationsFriends = true;
  bool _notificationsGeneral = true;
  String _theme = "light";

  // Getter
  bool get notifications => _notifications;
  bool get notificationsFriends => _notificationsFriends;
  bool get notificationsGeneral => _notificationsGeneral;
  String get theme => _theme;

  // Konstruktor
  AppSettings(this._firestoreService) {
    // Laden der Einstellungen beim Erstellen der Instanz
    loadSettings();
  }

  // Laden der Einstellungen von Firestore
  Future<void> loadSettings() async {
    try {
      Map<String, dynamic> settings = await _firestoreService.getUserSettings();
      _notifications = settings['notifications'] ?? true;
      _notificationsFriends = settings['notificationsFriends'] ?? true;
      _notificationsGeneral = settings['notificationsGeneral'] ?? true;
      _theme = settings['theme'] ?? "light";
      print("Geladene Einstellungen: $_theme"); // Debugging
      notifyListeners();
    } catch (e) {
      // Fehlerbehandlung
      print("Fehler beim Laden der Einstellungen: $e");
    }
  }

  // Aktualisieren der Einstellungen und Speichern in Firestore
  Future<void> updateSettings(Map<String, dynamic> updatedSettings) async {
    try {
      await _firestoreService.updateUserSettings(updatedSettings);
      // Lokale Kopie aktualisieren basierend auf den aktualisierten Einstellungen
      if (updatedSettings.containsKey('notifications')) {
        _notifications = updatedSettings['notifications'];
        if (!_notifications) {
          _notificationsFriends = false;
          _notificationsGeneral = false;
          // Entfernen der spezifischen Benachrichtigungen, wenn die Hauptbenachrichtigungen deaktiviert sind
          updatedSettings.remove('notificationsFriends');
          updatedSettings.remove('notificationsGeneral');
        }
      }
      if (updatedSettings.containsKey('notificationsFriends')) {
        _notificationsFriends = updatedSettings['notificationsFriends'];
      }
      if (updatedSettings.containsKey('notificationsGeneral')) {
        _notificationsGeneral = updatedSettings['notificationsGeneral'];
      }
      if (updatedSettings.containsKey('theme')) {
        _theme = updatedSettings['theme'];
        print("Theme aktualisiert zu: $_theme"); // Debugging
      }
      notifyListeners();
    } catch (e) {
      // Fehlerbehandlung
      print("Fehler beim Aktualisieren der Einstellungen: $e");
    }
  }

  // Methoden zum Aktualisieren einzelner Einstellungen
  void setTheme(String newTheme) {
    if (newTheme != "light" && newTheme != "dark") {
      throw ArgumentError("Ungültiger Theme-Wert");
    }
    _theme = newTheme;
    updateSettings({"theme": newTheme});
  }

  void setNotifications(bool value) {
    _notifications = value;
    if (!value) {
      _notificationsFriends = false;
      _notificationsGeneral = false;
      updateSettings({
        "notifications": value,
        "notificationsFriends": _notificationsFriends,
        "notificationsGeneral": _notificationsGeneral,
      });
    } else {
      updateSettings({"notifications": value});
    }
  }

  void setNotificationsFriends(bool value) {
    _notificationsFriends = value;
    updateSettings({"notificationsFriends": value});
  }

  void setNotificationsGeneral(bool value) {
    _notificationsGeneral = value;
    updateSettings({"notificationsGeneral": value});
  }
}