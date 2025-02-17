// lib/screens/profile_setup_screen.dart

import 'dart:io'; // Wichtig für File
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';  // Für Bildauswahl
import 'package:image_cropper/image_cropper.dart';   // Für Zuschneiden
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Für Komprimierung

import '../services/firestore_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Wählt ein Bild aus der Galerie, schneidet es zu und komprimiert es vor dem Upload
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, // erste Komprimierung schon beim Auswählen
      imageQuality: 90,
    );
    if (pickedFile != null) {
      File image = File(pickedFile.path);

      // Zuschneiden (auf quadratisches Format)
      File? croppedImage = await _cropImage(image);
      if (croppedImage == null) return;

      // Komprimieren
      File? compressedImage = await _compressImage(croppedImage);

      setState(() {
        _imageFile = compressedImage ?? File(croppedImage.path);
      });
    }
  }

  /// Schneidet das Bild auf ein quadratisches Format zu
  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Bild zuschneiden',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Bild zuschneiden',
        ),
      ],
    );
    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  /// Komprimiert das Bild, sodass es eine maximale Breite (und damit Größe) erreicht
  Future<File?> _compressImage(File imageFile) async {
    final targetPath = imageFile.path.replaceFirst('.jpg', '_compressed.jpg');
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.path,
      targetPath,
      quality: 85, // Komprimierungsqualität
      minWidth: 600, // Zielbreite
    );
    File? result = compressedFile != null ? File(compressedFile.path) : null;
    return result;
  }

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

      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

      // Falls ein Bild ausgewählt wurde, lade es hoch und aktualisiere das Profilbild
      if (_imageFile != null) {
        final profilePicUrl = await firestoreService.uploadProfilePicture(_imageFile!);
        await firestoreService.updateProfilePicture(profilePicUrl);
      }

      // Name in Firestore speichern
      await firestoreService.updateUserProfile({
        "displayName": name,
      });

      // Optional: FirebaseAuth-Profil ebenfalls aktualisieren
      await user.updateDisplayName(name);

      // Zurück zum HomeScreen
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
            // Profilbild-Auswahl: Bei Klick wird _pickImage aufgerufen
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            // Button zum Ändern des Profilbilds
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Profilbild ändern'),
            ),
            const SizedBox(height: 24),

            // Namenseingabe
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