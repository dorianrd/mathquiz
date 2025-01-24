// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// sign_in_button-Paket für offizielle Google/Apple-Buttons
import 'package:sign_in_button/sign_in_button.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart'; // Importiere FirestoreService

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Initialisiert die Nutzerdaten in Firestore nach erfolgreicher Anmeldung
  Future<void> _initializeUserData(User user) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.initializeUserDocument(user);
    } catch (e) {
      print("Fehler bei der Initialisierung der Nutzerdaten: $e");
      // Optional: Weitere Fehlerbehandlung, z.B. Snackbar anzeigen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler bei der Initialisierung der Nutzerdaten.')),
      );
    }
  }

  /// Anmeldung via E-Mail und Passwort
  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // Initialisiere Nutzerdaten in Firestore
        await _initializeUserData(user);

        // Anmeldung erfolgreich => Weiter zur Home-Seite
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      // Häufige Fehlercodes: user-not-found, invalid-credential, wrong-password
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-Mail unbekannt oder ungültige Daten.')),
        );
      } else if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falsches Passwort.')),
        );
      } else {
        // Andere Firebase-Fehler
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anmeldefehler: ${e.message}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      // Unbekannter Fehler
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unbekannter Anmeldefehler.')),
      );
      print('Allg. Fehler: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Anmeldung via Google
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithGoogle();
      if (user != null) {
        // Initialisiere Nutzerdaten in Firestore
        await _initializeUserData(user);

        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      // Google-spezifische Firebase-Fehler
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google-Anmeldung fehlgeschlagen: ${e.message}')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler bei der Google-Anmeldung')),
      );
      print('Allg. Fehler Google-Anmeldung: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Anmeldung via Apple (nur iOS/macOS)
  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithApple();
      if (user != null) {
        // Initialisiere Nutzerdaten in Firestore
        await _initializeUserData(user);

        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple-Anmeldung fehlgeschlagen: ${e.message}')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler bei der Apple-Anmeldung')),
      );
      print('Allg. Fehler Apple-Anmeldung: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToRegister() {
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmelden'),
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

              // Anmelden-Button (E-Mail/Passwort)
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Anmelden'),
                    ),

              const SizedBox(height: 20),

              // SignInButton für Google
              // (import 'package:sign_in_button/sign_in_button.dart')
              _isLoading
                  ? const SizedBox.shrink()
                  : SignInButton(
                      Buttons.google,
                      onPressed: _loginWithGoogle,
                    ),
              const SizedBox(height: 10),

              // SignInButton für Apple
              // (Buttons.AppleDark / Buttons.AppleLight je nach Designwunsch)
              _isLoading
                  ? const SizedBox.shrink()
                  : SignInButton(
                      Buttons.apple,
                      onPressed: _loginWithApple,
                    ),

              const SizedBox(height: 24),

              // Navigation zur Registrierungsseite
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Noch keinen Account?'),
                  TextButton(
                    onPressed: _navigateToRegister,
                    child: const Text('Registrieren'),
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