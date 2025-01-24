// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Simulieren einer Initialisierungszeit
      await Future.delayed(const Duration(seconds: 2));

      // Zugriff auf AuthService, um den aktuellen Benutzer zu prüfen
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Überprüfen, ob Benutzerprofil vorhanden ist
        Map<String, dynamic> userData = await firestoreService.getUserProfile();
        if (userData.isNotEmpty) {
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }

      // Wenn kein Benutzer angemeldet ist oder kein Profil vorhanden ist
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      // Bei Fehlern zur LoginScreen navigieren
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}