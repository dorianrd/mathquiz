// lib/screens/profile_setup_screen.dart

import 'dart:io'; // For File on mobile
import 'dart:typed_data'; // For Uint8List on web
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';  // For image picking on mobile
import 'package:image_cropper/image_cropper.dart';   // For cropping on mobile
import 'package:flutter_image_compress/flutter_image_compress.dart'; // For compressing on mobile
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart'; // For web file picking
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage

import '../services/firestore_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _profilePicUrl; // New variable to store the profile picture URL

  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Loads the user profile from Firestore and updates _profilePicUrl if available.
  void _loadProfile() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final profileData = await firestoreService.getUserProfile();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user is currently signed in.");
      return;
    }
    // If the user is signed in, try to get a fresh download URL for the profile picture.
    try {
      String newUrl = await FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile_picture.jpg')
          .getDownloadURL();
      print("Refreshed profile picture URL: $newUrl");
      profileData['profilePicture'] = newUrl;
      setState(() {
        _profilePicUrl = newUrl;
      });
    } catch (e) {
      print("Failed to refresh profile picture URL: $e");
    }
    setState(() {
      // Wrap the updated profile data in a Future.
      // Optionally, you could also update _profilePicUrl here if profileData already contains it.
    });
  }

  /// Picks an image from the gallery.
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

  /// Compresses the image.
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

  /// Uploads the image on the web.
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
      setState(() {
        _profilePicUrl = downloadURL;
      });
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

  /// Saves the profile. On mobile, if an image is selected, uploads it first.
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

      // On mobile, if an image was picked, upload it.
      if (!kIsWeb && _imageFile != null) {
        final profilePicUrl = await firestoreService.uploadProfilePicture(_imageFile!);
        await firestoreService.updateProfilePicture(profilePicUrl);
        setState(() {
          _profilePicUrl = profilePicUrl;
        });
      }

      // Save name in Firestore
      await firestoreService.updateUserProfile({"displayName": name});
      // Optionally update FirebaseAuth profile as well
      await user.updateDisplayName(name);

      // Navigate to HomeScreen
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
            // CircleAvatar now checks _profilePicUrl first.
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _profilePicUrl != null
                    ? NetworkImage(_profilePicUrl!)
                    : (_imageFile != null ? FileImage(_imageFile!) : null) as ImageProvider<Object>?,
                child: (_profilePicUrl == null && _imageFile == null)
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            // Button to change profile picture
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Profilbild ändern'),
            ),
            const SizedBox(height: 24),
            // Name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: const OutlineInputBorder(),
                labelStyle: themeData.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            // Save button
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