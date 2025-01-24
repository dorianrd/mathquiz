// lib/screens/profile_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Falls Sie AuthService/FirestoreService nutzen:
import '../services/firestore_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // AUSKOMMENTIERT: Felder und ImagePicker für Bild-Upload
  /*
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  */

  final TextEditingController _nameController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    // AUSKOMMENTIERT: _imageFile nicht mehr zurücksetzen
    /*
    _imageFile = null;
    */
    super.dispose();
  }

  // AUSKOMMENTIERT: Bildauswahl
  /*
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }
  */

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Namen eingeben')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kein Benutzer eingeloggt');
      }

      // AUSKOMMENTIERT: Falls Sie normalerweise ein Bild hochladen würden
      /*
      if (_imageFile != null) {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        final profilePicUrl = await firestoreService.uploadProfilePicture(_imageFile!);
        await firestoreService.updateProfilePicture(profilePicUrl);
      }
      */

      // Firestore updaten (Namen speichern)
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.updateUserProfile({
        "displayName": name,
        // AUSKOMMENTIERT: "profilePicture": profilePicUrl
      });

      // Optional: user.updateDisplayName(name)
      await user.updateDisplayName(name);

      // Jetzt fertig => Navigieren zum HomeScreen
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      print('Fehler beim Speichern des Profils: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Speichern des Profils')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil einrichten'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // AUSKOMMENTIERT: Profilbild-Auswahl
            /*
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : null,
                child: _imageFile == null
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
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
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: const OutlineInputBorder(),
                labelStyle: themeData.textTheme.bodyLarge,
              ),
            ),

            const SizedBox(height: 24),

            // Speichern-Button
            _isSaving
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Profil Speichern'),
                  ),
          ],
        ),
      ),
    );
  }
}