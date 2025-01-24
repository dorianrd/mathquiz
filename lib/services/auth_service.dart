// lib/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Anmeldung mit E-Mail und Passwort
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // Registrierung mit E-Mail und Passwort
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // Abmelden
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut(); // Google Sign-Out
      // Apple Sign-Out ist nicht erforderlich, da es serverseitig gehandhabt wird
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // Anmeldung mit Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Abgebrochen

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // Anmeldung mit Apple
  Future<User?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential result =
          await _auth.signInWithCredential(oauthCredential);
      return result.user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // Passwort aktualisieren
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("Keine angemeldeten Benutzer");
      }

      await user.updatePassword(newPassword);
      print("Passwort erfolgreich aktualisiert.");
    } catch (e) {
      print("Fehler beim Aktualisieren des Passworts: $e");
      throw e;
    }
  }

  // Neu: Konto löschen
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Kein Benutzer eingeloggt");
    }
    await user.delete();
    // Achtung: Evtl. "requires-recent-login" => Reauth wenn nötig
  }

  // Reauthentifizierung mit E-Mail und Passwort
  Future<void> reauthenticateWithEmailAndPassword(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("Keine angemeldeten Benutzer");
      }

      AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);
      print("Reauthentifizierung erfolgreich.");
    } catch (e) {
      print("Fehler bei der Reauthentifizierung: $e");
      throw e;
    }
  }
}