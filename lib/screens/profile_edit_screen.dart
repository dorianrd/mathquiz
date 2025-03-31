// lib/screens/profile_edit_screen.dart

import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:image_cropper/image_cropper.dart'; // For cropping images
import 'package:flutter_image_compress/flutter_image_compress.dart'; // For compressing images
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  // Fields for image upload
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  // We use a Future variable to load the profile (including the profile picture)
  Future<Map<String, dynamic>>? _profileFuture;

  bool _isEditingName = false;
  bool _isEditingEmail = false;
  bool _isEditingPassword = false;
  bool _isDeletingAccount = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile(); // Initial load of the profile
  }

  void _loadProfile() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    // Retrieve the user profile from Firestore.
    final profileData = await firestoreService.getUserProfile();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user is currently signed in.");
      return;
    }
    // If the user is signed in, we can try to get a fresh download URL for the profile picture.
    // This is useful if the user has changed their profile picture.
    if (user != null) {
      print("User is signed in: ${user.uid}");
      try {
        // Get a fresh download URL from Firebase Storage.
        String newUrl = await FirebaseStorage.instance
            .ref()
            .child('users')
            .child(user.uid)
            .child('profile_picture.jpg')
            .getDownloadURL();
        print("Refreshed profile picture URL: $newUrl");
        // Update the profile data with the fresh URL.
        profileData['profilePicture'] = newUrl;
      } catch (e) {
        print("Failed to refresh profile picture URL: $e");
      }
    }
    setState(() {
      // Wrap the updated profile data in a Future.
      _profileFuture = Future.value(profileData);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Picks an image from the gallery, crops it, compresses it, and then uploads it.
  Future<void> _pickImage() async {
    if (kIsWeb) {
      print("Running on web: using file_picker");
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final Uint8List? fileBytes = result.files.first.bytes;
        print("File picked on web, size: ${fileBytes?.lengthInBytes} bytes");
        if (fileBytes != null) {
          await _uploadProfilePictureWeb(fileBytes);
        }
      } else {
        print("No file selected on web.");
      }
    } else {
      // Mobile behavior:
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        print("Picked file: ${pickedFile.path}");
        File image = File(pickedFile.path);
        File? croppedImage = await _cropImage(image);
        if (croppedImage == null) {
          print("Image cropping cancelled or failed.");
          return;
        }
        File? compressedImage = await _compressImage(croppedImage);
        if (compressedImage != null) {
          print("Compressed image path: ${compressedImage.path}");
        } else {
          print("Compression failed; using cropped image.");
        }
        setState(() {
          _imageFile = compressedImage ?? croppedImage;
        });
        await _uploadProfilePicture();
      } else {
        print("No file picked.");
      }
    }
  }

  /// Crops the image to a square format.
  Future<File?> _cropImage(File imageFile) async {
    print("Cropping image at path: ${imageFile.path}");
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
    if (croppedFile == null) {
      print("Cropping cancelled.");
      return null;
    }
    print("Cropped image path: ${croppedFile.path}");
    return File(croppedFile.path);
  }

  /// Compresses the image so that it reaches a target width.
  Future<File?> _compressImage(File imageFile) async {
    final targetPath = imageFile.path.replaceFirst(RegExp(r'\.(jpg|jpeg|png)$'), '_compressed.jpg');
    print("Compressing image, target path: $targetPath");
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.path,
      targetPath,
      quality: 85,
      minWidth: 600,
    );
    if (compressedFile != null) {
      print("Compression succeeded, new file: ${compressedFile.path}");
      return File(compressedFile.path);
    } else {
      print("Compression failed.");
      return null;
    }
  }

  Future<void> _uploadProfilePictureWeb(Uint8List fileBytes) async {
    try {
      print("Uploading profile picture on web, byte size: ${fileBytes.lengthInBytes}");
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No signed-in user");
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile_picture.jpg');
      UploadTask uploadTask = ref.putData(fileBytes);
      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();
      print("Profile picture uploaded, URL: $downloadURL");
      await firestoreService.updateProfilePicture(downloadURL);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilbild aktualisiert')),
      );
      _loadProfile();
    } catch (e) {
      print("Error uploading profile picture on web: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Hochladen des Profilbildes')),
      );
    }
  }

  /// Uploads the image file to Firebase Storage and updates the profile picture in Firestore.
  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) return;
    try {
      print("Uploading profile picture from mobile, file: ${_imageFile!.path}");
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final downloadURL = await firestoreService.uploadProfilePicture(_imageFile!);
      print("Profile picture URL obtained: $downloadURL");
      await firestoreService.updateProfilePicture(downloadURL);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilbild aktualisiert')),
      );
      _loadProfile();
    } catch (e) {
      print('Fehler beim Hochladen des Profilbildes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren des Profilbildes')),
      );
    }
  }

  // Name bearbeiten
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
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.updateUserProfile({"displayName": newName});
      setState(() {
        _isEditingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name aktualisiert')),
      );
      _loadProfile(); // Profildaten neu laden
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren des Namens')),
      );
      print('Fehler beim Speichern des Namens: $e');
    }
  }

  // E-Mail bearbeiten
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
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        await firestoreService.updateUserProfile({"email": newEmail});

        setState(() => _isEditingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-Mail aktualisiert')),
        );
        _loadProfile();
      }
    } catch (e) {
      print('Fehler beim Aktualisieren der E-Mail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren der E-Mail')),
      );
    }
  }

  // Passwort bearbeiten
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

  // Logout
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

  // Confirm Account Deletion
  Future<void> _confirmDeleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Account löschen'),
          content: const Text(
            'Möchtest du deinen Account wirklich löschen?\nDiese Aktion ist endgültig.',
          ),
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
      _deleteAccount();
    }
  }

  // Account-Löschlogik
  Future<void> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.deleteAccount();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } on FirebaseAuthException catch (e) {
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
    // In der Future laden wir das Profilbild aus der Datenbank
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profil Einstellungen')),
            body: Center(child: Text('Fehler: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profil Einstellungen')),
            body: const Center(child: Text('Keine Daten gefunden')),
          );
        }

        final userData = snapshot.data!;
        displayName = userData['displayName'] ?? (user?.displayName ?? '');
        email = userData['email'] ?? (user?.email ?? '');
        final profilePicture = userData['profilePicture'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profil Einstellungen'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Anzeige des aktuellen Profilbildes im CircleAvatar
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: profilePicture.isNotEmpty
                        ? NetworkImage(profilePicture)
                        : (_imageFile != null ? FileImage(_imageFile!) : null) as ImageProvider<Object>?,
                    child: (profilePicture.isEmpty && _imageFile == null)
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                // Button zum Ändern des Profilbilds
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Profilbild ändern'),
                ),
                const SizedBox(height: 24),

                // Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                      'Name: $displayName',
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      ),
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
                    Expanded(
                      child: Text(
                        'E-Mail: $email',
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

                // Passwort (nur anzeigen, wenn mit E-Mail/Passwort angemeldet)
                if (user != null &&
                    user.providerData.any((provider) => provider.providerId == 'password'))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Passwort: ******',
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
                  label: const Text('Abmelden', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                        label: const Text('Konto löschen', style: TextStyle(color: Colors.white, fontSize: 16)),
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