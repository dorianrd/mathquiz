// lib/screens/friends/friend_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';

class FriendDetailScreen extends StatelessWidget {
  final Map<String, dynamic> friendData;
  const FriendDetailScreen({Key? key, required this.friendData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final friendName = friendData["displayName"] ?? "Unbekannt";
    final profilePic = friendData["profilePicture"] ?? "";

    return Scaffold(
      appBar: AppBar(
        title: Text(friendName),
      ),
      body: SingleChildScrollView( // Ermöglicht Scrollen bei kleinem Bildschirm
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.topCenter, // Vertikale Ausrichtung am oberen Rand
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Horizontale Zentrierung
              children: [
                // Profilbild anzeigen
                CircleAvatar(
                  radius: 60,
                  backgroundImage: profilePic.isNotEmpty
                      ? NetworkImage(profilePic)
                      : null,
                  child: profilePic.isEmpty ? const Icon(Icons.person, size: 60) : null,
                ),
                const SizedBox(height: 24), // Erhöhter Abstand
                //Text(
                //  'Name: $friendName',
                //  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                //  textAlign: TextAlign.center, // Zentriert den Text innerhalb des TextWidgets
                //),
                const SizedBox(height: 24), // Erhöhter Abstand
                // Button: Duell/1v1-Einladen
                /*ElevatedButton(
                  onPressed: () {
                    // Hier kannst du die Logik zum Einladen zu einem Duell implementieren
                    // Zum Beispiel, eine Spielanfrage senden oder eine Duell-Routine starten
                    print("Einladung an $friendName geschickt!");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Einladung an $friendName geschickt!")),
                    );
                  },
                  child: const Text('Einladen zum Duell'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                */
                const SizedBox(height: 24), // Erhöhter Abstand
                // Button: Freund entfernen
                ElevatedButton(
                  onPressed: () async {
                    final firestore = Provider.of<FirestoreService>(context, listen: false);
                    try {
                      await firestore.removeFriend(friendData['uid']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Freund $friendName entfernt.')),
                      );
                      Navigator.pop(context); // Zurück zum FriendsScreen
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: ${e.toString()}')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Rot
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Freund entfernen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}