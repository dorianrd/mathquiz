// lib/screens/profile_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Eigene Importe
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  // ------------------------------------------
  // AUSKOMMENTIERT: Felder für Bild-Upload
  // ------------------------------------------
  /*
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  */

  bool _isEditingName = false;
  bool _isEditingEmail = false;
  bool _isEditingPassword = false;
  bool _isDeletingAccount = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // ------------------------------------------
    // AUSKOMMENTIERT: Setzen wir _imageFile nicht mehr zurück, 
    //                da das Feature deaktiviert ist
    // ------------------------------------------
    /*
    _imageFile = null;
    */
    super.dispose();
  }

  // ------------------------------------------
  // AUSKOMMENTIERT: Foto-Aufnahme/Upload
  // ------------------------------------------
  /*
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadProfilePicture();
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) return;

    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      String downloadURL =
          await firestoreService.uploadProfilePicture(_imageFile!);
      await firestoreService.updateProfilePicture(downloadURL);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilbild aktualisiert')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren des Profilbildes')),
      );
      print('Fehler beim Hochladen des Profilbildes: $e');
    }
  }
  */

  // Name-Editing
  void _editName(String currentName) {
    setState(() {
      _isEditingName = true;
      _nameController.text = currentName;
    });
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name darf nicht leer sein')),
      );
      return;
    }

    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.updateUserProfile({"displayName": newName});
      setState(() {
        _isEditingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name aktualisiert')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren des Namens')),
      );
      print('Fehler beim Speichern des Namens: $e');
    }
  }

  // E-Mail-Editing
  void _editEmail(String currentEmail) {
    setState(() {
      _isEditingEmail = true;
      _emailController.text = currentEmail;
    });
  }

  Future<void> _saveEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail darf nicht leer sein')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(newEmail);
        final firestoreService =
            Provider.of<FirestoreService>(context, listen: false);
        await firestoreService.updateUserProfile({"email": newEmail});

        setState(() => _isEditingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-Mail aktualisiert')),
        );
      }
    } catch (e) {
      print('Fehler beim Aktualisieren der E-Mail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren der E-Mail')),
      );
    }
  }

  // Passwort-Editing
  void _editPassword() {
    setState(() {
      _isEditingPassword = true;
      _passwordController.clear();
    });
  }

  Future<void> _savePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort darf nicht leer sein')),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updatePassword(newPassword);
      setState(() => _isEditingPassword = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort aktualisiert')),
      );
    } catch (e) {
      print('Fehler beim Aktualisieren des Passworts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren des Passworts')),
      );
    }
  }

  // Abmelden
  Future<void> _logout() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Abmelden')),
      );
      print("Fehler beim Abmelden: $e");
    }
  }

  /// Zeigt ein PopUp an „Möchtest du deinen Account wirklich löschen?“
  /// Wenn bestätigt => `_deleteAccount()`
  Future<void> _confirmDeleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Account löschen?'),
          content: const Text('Möchtest du deinen Account wirklich löschen?\nDiese Aktion ist endgültig.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Benutzer hat bestätigt => Account löschen
      _deleteAccount();
    }
  }

  /// Führt die eigentliche Lösch-Logik aus.
  Future<void> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.deleteAccount(); // -> s. AuthService

      // Nach dem Löschen z. B. zum Login-Screen leiten
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

    } on FirebaseAuthException catch (e) {
      // Häufig: requires-recent-login => Reauth erforderlich
      print('FirebaseAuthException beim Löschen: ${e.code} | ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen: ${e.message}')),
      );
    } catch (e) {
      print('Allgemeiner Fehler beim Löschen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account konnte nicht gelöscht werden.')),
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final user = FirebaseAuth.instance.currentUser;

    String displayName = '';
    String email = '';
    String profilePicture = '';

    if (user != null) {
      displayName = user.displayName ?? '';
      email = user.email ?? '';
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: firestoreService.getUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profil Einstellungen')),
            body: Center(
              child: Text('Fehler: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profil Einstellungen')),
            body: const Center(child: Text('Keine Daten gefunden')),
          );
        }

        final userData = snapshot.data!;
        displayName = userData['displayName'] ?? displayName;
        email = userData['email'] ?? email;
        profilePicture = userData['profilePicture'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profil Einstellungen'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ------------------------------------------
                // AUSKOMMENTIERT: Profilbild ändern
                // ------------------------------------------
                /*
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: profilePicture.isNotEmpty
                        ? NetworkImage(profilePicture) as ImageProvider
                        : null,
                    child: profilePicture.isEmpty
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Profilbild ändern',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 24),
                */
                // Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Name: $displayName',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editName(displayName),
                    ),
                  ],
                ),
                if (_isEditingName)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Neuer Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() => _isEditingName = false);
                              },
                              child: const Text('Abbrechen'),
                            ),
                            ElevatedButton(
                              onPressed: _saveName,
                              child: const Text('Speichern'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // E-Mail
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'E-Mail: $email',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editEmail(email),
                    ),
                  ],
                ),
                if (_isEditingEmail)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Neue E-Mail',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() => _isEditingEmail = false);
                              },
                              child: const Text('Abbrechen'),
                            ),
                            ElevatedButton(
                              onPressed: _saveEmail,
                              child: const Text('Speichern'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Passwort (nur anzeigen, wenn mit E-Mail und Passwort angemeldet)
                if (user != null &&
                    user.providerData
                        .any((provider) => provider.providerId == 'password'))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Passwort:',
                            style: TextStyle(fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _editPassword,
                          ),
                        ],
                      ),
                      if (_isEditingPassword)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: 'Neues Passwort',
                                  border: OutlineInputBorder(),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _isEditingPassword = false);
                                    },
                                    child: const Text('Abbrechen'),
                                  ),
                                  ElevatedButton(
                                    onPressed: _savePassword,
                                    child: const Text('Speichern'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 32),

                // Abmelden Button
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Abmelden',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),

                const SizedBox(height: 16),

                // Konto Löschen
                _isDeletingAccount
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _confirmDeleteAccount,
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text(
                          'Konto löschen',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}