// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:mathquiz/screens/components/components.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../services/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Zugriff auf AppSettings
    final appSettings = Provider.of<AppSettings>(context);
    final ThemeData themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Einstellungen Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/profile_edit');
                },
                icon: Icon(
                  Icons.person,
                  size: 24,
                  color: themeData.colorScheme.onPrimary, // Textfarbe basierend auf Theme
                ),
                label: Text(
                  'Profil Einstellungen',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeData.colorScheme.onPrimary, // Textfarbe basierend auf Theme
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Angepasste Größe
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // Weniger rund
                  ),
                  elevation: 2, // Weniger Hervorhebung
                  backgroundColor: themeData.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Benachrichtigungseinstellungen Box
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400), // Rahmen hinzufügen
                borderRadius: BorderRadius.circular(8.0), // Weniger rund
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Benachrichtigungseinstellungen',
                    style: themeData.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Benachrichtigungen an'),
                    value: appSettings.notifications,
                    onChanged: (bool value) {
                      appSettings.setNotifications(value);
                    },
                  ),
                  if (appSettings.notifications) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Benachrichtigungen zum Spielen mit Freunden an'),
                            value: appSettings.notificationsFriends,
                            onChanged: (bool value) {
                              appSettings.setNotificationsFriends(value);
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Allgemeine Benachrichtigungen an'),
                            value: appSettings.notificationsGeneral,
                            onChanged: (bool value) {
                              appSettings.setNotificationsGeneral(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Theme Auswahl
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Thema',
                icon: const Icon(Icons.brightness_6),
                labelStyle: themeData.textTheme.bodyLarge,
              ),
              value: appSettings.theme,
              items: [
                DropdownMenuItem(
                  value: "light",
                  child: Text(
                    "Hell",
                    style: themeData.textTheme.bodyLarge,
                  ),
                ),
                DropdownMenuItem(
                  value: "dark",
                  child: Text(
                    "Dunkel",
                    style: themeData.textTheme.bodyLarge,
                  ),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  appSettings.setTheme(newValue);
                }
              },
              style: themeData.textTheme.bodyLarge, // DropdownButton's text style
              iconEnabledColor: themeData.iconTheme.color,
              dropdownColor: themeData.colorScheme.surface, // Dropdown background color
            ),
            const SizedBox(height: 16),

            // Datenschutzrichtlinie
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/privacy_policy');
                },
                child: Text(
                  'Datenschutzrichtlinie',
                  style: TextStyle(
                    color: themeData.colorScheme.primary,
                    decoration: TextDecoration.underline,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Spacer für Push nach unten
            const SizedBox(height: 100),

            // Abmelden Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  _logout(context);
                },
                icon: Icon(
                  Icons.logout,
                  color: themeData.colorScheme.onPrimary,
                ),
                label: Text(
                  'Abmelden',
                  style: TextStyle(
                    color: themeData.colorScheme.onPrimary,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abmelden
  void _logout(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      // Fehlerbehandlung
      ErrorNotifier.show(context, 'Fehler beim Abmelden');
      print("Fehler beim Abmelden: $e");
    }
  }
}