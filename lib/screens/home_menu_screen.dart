// lib/screens/home_menu_screen.dart

import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'menu/menu_screen.dart';
// ↓ Neu: Wir binden hier unsere eigenständige friends_screen.dart ein
import 'friends/friends_screen.dart';

class HomeMenuScreen extends StatefulWidget {
  const HomeMenuScreen({super.key});

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen> {
  int _currentIndex = 0;

  // Liste der Widgets für jede Tab
  final List<Widget> _children = [
    const MenuScreen(),      // <-- Neues separates Widget in menu_screen.dart
    const FriendsScreen(),   // <-- Neu: Aus friends_screen.dart
    const SettingsScreen(),  // <-- Bestehendes SettingsScreen
  ];

  // Titel für die AppBar basierend auf dem aktuellen Tab
  final List<String> _titles = [
    'Menü',
    'Freunde',
    'Einstellungen',
  ];

  // Methode zum Wechseln des Tabs
  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Entfernt den automatischen Zurück-Button
        automaticallyImplyLeading: false,
        // Titel/Überschrift je nach aktuellem Tab
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _titles[_currentIndex],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        // Profil-Icon nur anzeigen, wenn _currentIndex != 2 (Einstellungen)
        actions: _currentIndex != 2
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(
                        Icons.person,
                        color: Colors.black87,
                      ),
                      onPressed: () {
                        // Aktion beim Klicken des Profil-Buttons
                        Navigator.pushNamed(context, '/profile_edit');
                      },
                    ),
                  ),
                ),
              ]
            : [],
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,            // Methode zum Wechseln des Tabs
        currentIndex: _currentIndex,   // Aktueller Tab
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'Menü',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Freunde',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}