// lib/screens/menu/modi/onevone_menu_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/firestore_service.dart';
import '../modi/onevone/onevone_sync_screen.dart';

class OneVOneMenuScreen extends StatefulWidget {
  const OneVOneMenuScreen({Key? key}) : super(key: key);

  @override
  State<OneVOneMenuScreen> createState() => _OneVOneMenuScreenState();
}

class _OneVOneMenuScreenState extends State<OneVOneMenuScreen> {
  StreamSubscription? _ingameSubscription;
  List<Map<String, dynamic>> _friendList = [];
  List<Map<String, dynamic>> _incomingInvitations = [];
  List<Map<String, dynamic>> _gameHistory = [];
  String? _selectedFriendUid;
  String? _selectedFriendName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriendList();
    _loadIncomingInvitations();
    _loadGameHistory();
    _startIngameListener();
  }

  @override
  void dispose() {
    _ingameSubscription?.cancel();
    super.dispose();
  }

  /// Nutzt einen Realtime-Listener, um zu prüfen, ob für den aktuellen Nutzer eine Einladung existiert,
  /// bei der das Feld "ingame" bereits true ist – dann wird zum SyncScreen navigiert, sofern die Einladung
  /// nicht bereits abgeschlossen ist.
  void _startIngameListener() {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _ingameSubscription = firestore.db
        .collection('onevone_invitations')
        .where('participants', arrayContains: user.uid)
        .where('ingame', isEqualTo: true)
        .snapshots()
        .listen((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        if (!doc.exists) {
          print('Dokument existiert nicht mehr.');
          return;
        }
        final data = doc.data() as Map<String, dynamic>;
        // Navigiere nur, wenn die Einladung noch nicht abgeschlossen ist.
        if (data['status'] != 'abgeschlossen') {
          String invitationId = doc.id;
          _ingameSubscription?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OneVOneSyncScreen(invitationId: invitationId),
            ),
          );
        } else {
          print('Gefundene Einladung ist bereits abgeschlossen.');
        }
      }
    }, onError: (error) {
      print('Error in _startIngameListener: $error');
      _ingameSubscription?.cancel();
    });
  }

  Future<void> _loadFriendList() async {
    setState(() => _isLoading = true);
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      _friendList = await firestore.getFriendsList();
    } catch (e) {
      print("Fehler beim Laden der Freundesliste: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadIncomingInvitations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    // Hier wird gezielt nach 'toUid' gefiltert, sodass nur Einladungen erscheinen, die der Nutzer erhalten hat.
    QuerySnapshot snapshot = await firestore.db
      .collection('onevone_invitations')
      .where('participants', arrayContains: user.uid)
      .where('status', isEqualTo: 'pending')
      .get();
    setState(() {
      _incomingInvitations = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> _loadGameHistory() async {
    // Lade die Spielhistorie aus dem Nutzer-Dokument unter scores.onevone.history
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    DocumentSnapshot userDoc =
        await firestore.db.collection('users').doc(user.uid).get();
    Map<String, dynamic> history = {};
    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      if (data.containsKey('scores') &&
          data['scores'].containsKey('onevone') &&
          data['scores']['onevone'].containsKey('history')) {
        history = data['scores']['onevone']['history'] as Map<String, dynamic>;
      }
    }
    List<Map<String, dynamic>> gameHistory = [];
    history.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        var game = value;
        game['id'] = key;
        gameHistory.add(game);
      }
    });
    gameHistory.sort((a, b) {
      Timestamp aTime = a['timestamp'] ?? Timestamp(0, 0);
      Timestamp bTime = b['timestamp'] ?? Timestamp(0, 0);
      return bTime.compareTo(aTime);
    });
    setState(() {
      _gameHistory = gameHistory;
    });
  }

  /// Sendet eine Einladung an den ausgewählten Freund.
  Future<void> _sendInvitation() async {
    if (_selectedFriendUid == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    Map<String, dynamic> invitation = {
      'fromUid': user.uid,
      'fromName': user.displayName ?? 'Unbekannter',
      'toUid': _selectedFriendUid,
      'toName': _selectedFriendName,
      'status': 'pending',
      'round': 1,
      'ingame': false, // Wird später auf true gesetzt, wenn das Spiel startet
      'participants': [user.uid, _selectedFriendUid],
    };
    await firestore.sendOneVOneInvitation(invitation);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Einladung gesendet")),
    );
    _loadIncomingInvitations();
  }

  /// Akzeptiert eine eingehende Einladung.
  Future<void> _acceptInvitation(String invitationId) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    await firestore.db.collection('onevone_invitations').doc(invitationId).update({
      'status': 'accepted',
      'ingame': true, // Sobald angenommen, ist das Spiel ready
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OneVOneSyncScreen(invitationId: invitationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("1v1 Modus – Menü"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bereich: Einladung senden
                  const Text("Freund auswählen und einladen", style: TextStyle(fontSize: 18)),
                  DropdownButton<String>(
                    hint: const Text("Freund auswählen"),
                    value: _selectedFriendUid,
                    items: _friendList.map((friend) {
                      return DropdownMenuItem<String>(
                        value: friend['uid'],
                        child: Text(friend['displayName']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFriendUid = value;
                        _selectedFriendName = _friendList.firstWhere((f) => f['uid'] == value)['displayName'];
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: _sendInvitation,
                    child: const Text("Einladung senden"),
                  ),
                  const Divider(),
                  // Bereich: Eingehende Einladungen
                  const Text("Eingehende Einladungen", style: TextStyle(fontSize: 18)),
                  ..._incomingInvitations.map((invitation) {
                    return ListTile(
                      title: Text("Einladung von ${invitation['fromName']}"),
                      subtitle: Text("Status: ${invitation['status']}"),
                      trailing: ElevatedButton(
                        onPressed: () => _acceptInvitation(invitation['id']),
                        child: const Text("Annehmen"),
                      ),
                    );
                  }).toList(),
                  const Divider(),
                  // Bereich: Spielverlauf (aus Nutzer-Daten)
                  const Text("Spielverlauf", style: TextStyle(fontSize: 18)),
                  ..._gameHistory.map((game) {
                    return ListTile(
                      title: Text("Spiel ${game['id']}"),
                      subtitle: Text(
                          "Score: ${game['score']}, Runde: ${game['round']}, Ergebnis: ${game['state']}"),
                      trailing: Text(
                        game.containsKey("timestamp")
                            ? (game["timestamp"] as Timestamp).toDate().toString()
                            : "",
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}