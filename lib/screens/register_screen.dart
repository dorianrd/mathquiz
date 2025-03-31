// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte alle Felder ausfüllen.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Registrierung via E-Mail/Passwort
      final user = await authService.register(
        email,
        password,
      );

      if (user != null) {
        // Initialisiere das vollständige Benutzer-Dokument in Firestore (falls nicht vorhanden)
        await firestoreService.initializeUserDocumentIfNotExists(user);

        // Weiterleitung zum Profil-Setup, wo der Name gesetzt wird
        Navigator.pushReplacementNamed(context, '/profile_setup');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      // Firebase-spezifische Fehler
      if (e.code == 'weak-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Das Passwort ist zu schwach.')),
        );
      } else if (e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diese E-Mail ist schon registriert.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registrierungsfehler: ${e.message}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Unbekannter Fehler
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unbekannter Fehler bei der Registrierung')),
      );
      print('Allg. Fehler: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrieren'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // E-Mail TextField
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-Mail',
                  border: const OutlineInputBorder(),
                  labelStyle: themeData.textTheme.bodyLarge,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Passwort TextField
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  border: const OutlineInputBorder(),
                  labelStyle: themeData.textTheme.bodyLarge,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // Registrieren Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text('Registrieren'),
                    ),
              const SizedBox(height: 24),

              // Navigation zur Login-Seite
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Bereits ein Konto?'),
                  TextButton(
                    onPressed: _navigateToLogin,
                    child: const Text('Anmelden'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}