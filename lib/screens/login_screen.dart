import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// sign_in_button package for official Google/Apple buttons
import 'package:sign_in_button/sign_in_button.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart'; // FirestoreService is needed

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

  /// Initializes the user data in Firestore after successful login.
  Future<void> _initializeUserData(User user) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.initializeUserDocumentIfNotExists(user);
    } catch (e) {
      print("Error initializing user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error initializing user data.')),
      );
    }
  }

  /// Sign in via Email and Password.
  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // Initialize user data in Firestore
        await _initializeUserData(user);

        // Successful login => Navigate to Home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email unknown or invalid credentials.')),
        );
      } else if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong password.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login error: ${e.message}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unknown login error.')),
      );
      print('General error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Resets the password (sends a password reset email).
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unknown error during password reset.')),
      );
    }
  }

  /// Sign in via Google with explicit clientId.
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Pass the clientId explicitly for web configuration.
      final user = await authService.signInWithGoogle(
          clientId: "427680799387-c8omd0ltb2dc4htgde4paaj8rek7hqqd.apps.googleusercontent.com");
      if (user != null) {
        // Initialize user data in Firestore
        await _initializeUserData(user);

        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-in fehlgeschlagen: ${e.message}')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler während der Anmeldung mit Google')),
      );
      print('Genereller Fehler während der Anmeldung mit Google: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Sign in via Apple (only for iOS/macOS)
  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithApple();
      if (user != null) {
        // Initialize user data in Firestore
        await _initializeUserData(user);

        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign-in failed: ${e.message}')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error during Apple sign-in')),
      );
      print('General error during Apple sign-in: $e');
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Logo oben platzieren
              Image.asset(
                'assets/images/mathquiz_logo.png',  // Pfad zu deinem Logo
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),

              // Email TextField
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

              // Password TextField
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  border: const OutlineInputBorder(),
                  labelStyle: themeData.textTheme.bodyLarge,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),

              // "Forgot Password?" Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: const Text('Passwort vergessen?'),
                ),
              ),

              const SizedBox(height: 16),

              // Sign in Button (Email/Password)
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

              // SignInButton for Google
              _isLoading
                  ? const SizedBox.shrink()
                  : SignInButton(
                      Buttons.google,
                      onPressed: _loginWithGoogle,
                    ),
              const SizedBox(height: 10),

              // SignInButton for Apple (optional)
              // _isLoading
              //     ? const SizedBox.shrink()
              //     : SignInButton(
              //         Buttons.apple,
              //         onPressed: _loginWithApple,
              //       ),

              const SizedBox(height: 24),

              // Navigation to Registration screen
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Noch kein Konto?'),
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