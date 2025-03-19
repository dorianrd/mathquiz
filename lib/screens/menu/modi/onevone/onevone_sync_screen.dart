// lib/screens/menu/modi/onevone_sync_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onevone_game_screen.dart';
import 'package:mathquiz/services/firestore_service.dart';

class OneVOneSyncScreen extends StatefulWidget {
  final String invitationId;
  const OneVOneSyncScreen({Key? key, required this.invitationId}) : super(key: key);

  @override
  _OneVOneSyncScreenState createState() => _OneVOneSyncScreenState();
}

class _OneVOneSyncScreenState extends State<OneVOneSyncScreen> {
  bool _isButtonPressed = false; // Steuert den Buttonstatus für den Eingeladenen

  /// Markiert den aktuellen Spieler als bereit.
  /// - Falls der aktuelle Nutzer der Sender ist, wird automatisch das Feld `readyFrom` gesetzt.
  /// - Falls der Nutzer der Empfänger ist, wird beim Button-Klick das Feld `readyTo` gesetzt.
  Future<void> _markReady(DocumentReference docRef, Map<String, dynamic> invitationData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String fieldKey;
    if (user.uid == invitationData['fromUid']) {
      // Sender: Bereitschaft automatisch setzen
      fieldKey = 'readyFrom';
    } else {
      // Eingeladener: Bereitschaft über Button
      fieldKey = 'readyTo';
    }
    await docRef.update({fieldKey: true});
  }

  /// Prüft, ob beide Spieler als bereit markiert sind.
  /// Falls ja und der Status noch nicht auf "in_progress" gesetzt ist, wird dies aktualisiert.
  Future<void> _checkAndStartGame(DocumentReference docRef, Map<String, dynamic> invitationData) async {
    bool readyFrom = invitationData['readyFrom'] == true;
    bool readyTo = invitationData['readyTo'] == true;
    if (readyFrom && readyTo && invitationData['status'] != 'in_progress') {
      await docRef.update({'status': 'in_progress'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.db.collection('onevone_invitations').doc(widget.invitationId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text("Synchronisation")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Synchronisation")),
            body: const Center(child: Text("Einladung nicht gefunden.")),
          );
        }
        final invitationData = snapshot.data!.data() as Map<String, dynamic>;
        final docRef = firestore.db.collection('onevone_invitations').doc(widget.invitationId);

        // Falls der Status bereits "in_progress" ist, leite direkt in den Game-Screen weiter.
        if (invitationData['status'] == 'in_progress') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OneVOneGameScreen(
                  invitation: {
                    ...invitationData,
                    'id': widget.invitationId,
                  },
                ),
              ),
            );
          });
          return Scaffold(
            appBar: AppBar(title: const Text("Synchronisation")),
            body: const Center(child: Text("Spiel startet...")),
          );
        }

        // Sender wird automatisch als bereit markiert, falls noch nicht erfolgt.
        if (user != null && user.uid == invitationData['fromUid'] && invitationData['readyFrom'] != true) {
          _markReady(docRef, invitationData);
        }

        // Bestimme, ob der aktuelle Nutzer der Empfänger ist und ob er bereits bereit ist.
        bool isReceiver = user != null && user.uid == invitationData['toUid'];
        bool receiverReady = invitationData['readyTo'] == true;

        // Prüfe, ob beide Spieler bereit sind und starte das Spiel, falls zutreffend.
        _checkAndStartGame(docRef, invitationData);

        return Scaffold(
          appBar: AppBar(title: const Text("Synchronisation")),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Warte darauf, dass der andere Spieler bereit ist..."),
                const SizedBox(height: 20),
                const LinearProgressIndicator(),
                const SizedBox(height: 20),
                if (isReceiver && !receiverReady)
                  ElevatedButton(
                    onPressed: _isButtonPressed
                        ? null
                        : () async {
                            setState(() {
                              _isButtonPressed = true;
                            });
                            await _markReady(docRef, invitationData);
                          },
                    child: const Text("Ich bin bereit"),
                  ),
                if (isReceiver && receiverReady)
                  const Text("Du hast deine Bereitschaft signalisiert."),
              ],
            ),
          ),
        );
      },
    );
  }
}