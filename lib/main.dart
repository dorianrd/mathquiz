// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:provider/provider.dart';

// Services
import 'services/firestore_service.dart';
import 'services/app_settings.dart';
import 'services/auth_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/home_menu_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_edit_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/menu/modi/daily_challenge.dart';

// Spielmodi und Freunde
import 'screens/menu/modi/kopf_rechnen.dart';
import 'screens/friends/friends_screen.dart';

// 1v1 Screens
import 'screens/menu/modi/onevone.dart';

// Lernmodus
import 'screens/menu/modi/lernen.dart';
import 'screens/menu/modi/lernlevel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<AppSettings>(
          create: (context) => AppSettings(Provider.of<FirestoreService>(context, listen: false)),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final appSettings = Provider.of<AppSettings>(context);
    final bool isDarkMode = (appSettings.theme == "dark");
    return MaterialApp(
      title: 'Math Quiz App',
      theme: isDarkMode ? _darkTheme() : _lightTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeMenuScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile_edit': (context) => const ProfileEditScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/privacy_policy': (context) => const PrivacyPolicyScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/kopf_rechnen': (context) => const KopfRechnenScreen(),
        '/daily_challenge': (context) => const DailyChallengeScreen(),
        '/friends': (context) => const FriendsScreen(),
        // 1v1 Routen
        '/onevone': (context) => const OneVOneMenuScreen(),

        '/lernen': (context) => const LearningModeScreen(),
        //'/lernen_level': (context) => const LearningLevelScreen(),
      },
    );
  }

  ThemeData _lightTheme() {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black87, decoration: TextDecoration.none),
        bodyMedium: TextStyle(color: Colors.black87, decoration: TextDecoration.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.deepPurple,
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Colors.black87),
      ),
    );
  }

  ThemeData _darkTheme() {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, decoration: TextDecoration.none),
        bodyMedium: TextStyle(color: Colors.white, decoration: TextDecoration.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.deepPurple,
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}