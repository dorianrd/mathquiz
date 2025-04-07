import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firestore_service.dart';
import 'onevone/onevone_waiting.dart';

class OneVOneMenuScreen extends StatefulWidget {
  const OneVOneMenuScreen({Key? key}) : super(key: key);

  @override
  _OneVOneMenuScreenState createState() => _OneVOneMenuScreenState();
}

class _OneVOneMenuScreenState extends State<OneVOneMenuScreen> {
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      final friendsList = await firestoreService.getFriendsList();
      setState(() {
        _friends = friendsList;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Freunde: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadGameHistory() async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    // Query für Spiele, bei denen der aktuelle Nutzer als Sender finished ist
    final querySender = await firestoreService.db
        .collection('onevone_invitations')
        .where("UIDSender", isEqualTo: currentUserId)
        .where("StatusSender", whereIn: ["won", "loss", "tie"])
        .get();
    // Query für Spiele, bei denen der aktuelle Nutzer als Receiver finished ist
    final queryReceiver = await firestoreService.db
        .collection('onevone_invitations')
        .where("UIDReceiver", isEqualTo: currentUserId)
        .where("StatusReceiver", whereIn: ["won", "loss", "tie"])
        .get();
    List<Map<String, dynamic>> history = [];
    for (var doc in querySender.docs) {
      var data = doc.data();
      data["id"] = doc.id;
      history.add(data);
    }
    for (var doc in queryReceiver.docs) {
      var data = doc.data();
      data["id"] = doc.id;
      history.add(data);
    }
    // Sortiere nach TimeStamp (neueste zuerst), sofern vorhanden.
    history.sort((a, b) {
      final t1 = a["TimeStamp"] as Timestamp?;
      final t2 = b["TimeStamp"] as Timestamp?;
      if (t1 == null || t2 == null) return 0;
      return t2.compareTo(t1);
    });
    return history;
  }

  Future<void> _sendInvitation(Map<String, dynamic> friend) async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein Nutzer angemeldet.')),
      );
      return;
    }
    final senderName = currentUser.displayName ?? 'Unbekannt';
    final uidSender = currentUser.uid;
    final receiverName = friend['displayName'] ?? 'Unbekannt';
    final uidReceiver = friend['uid'];

    try {
      final invitationId = await firestoreService.sendOneVoneInvitation(
        nameSender: senderName,
        nameReceiver: receiverName,
        uidSender: uidSender,
        uidReceiver: uidReceiver,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Einladung an $receiverName gesendet.')),
      );
      // Navigiere in den Wartebildschirm und übergebe die Einladung-ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OneVOneWaitingScreen(invitationId: invitationId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Senden der Einladung: $e')),
      );
    }
  }

  Future<void> _acceptInvitation(Map<String, dynamic> invitation) async {
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.acceptOneVOneInvitation(invitation['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einladung angenommen.')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OneVOneWaitingScreen(invitationId: invitation['id']),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Annehmen der Einladung: $e')),
      );
    }
  }

  Future<void> _rejectInvitation(Map<String, dynamic> invitation) async {
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.rejectOneVOneInvitation(invitation['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einladung abgelehnt.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Ablehnen der Einladung: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1v1 Menü'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Neuer Abschnitt: Einladungen
                    const Text(
                      'Einladungen',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: Provider.of<FirestoreService>(context, listen: false)
                          .db
                          .collection('onevone_invitations')
                          .where('UIDReceiver',
                              isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                          .where('StatusReceiver', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text(
                            "Keine Einladungen vorhanden.",
                            textAlign: TextAlign.center,
                          );
                        }
                        final invitations = snapshot.data!.docs;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: invitations.length,
                          itemBuilder: (context, index) {
                            final invitation = invitations[index].data();
                            final invitationId = invitations[index].id;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  "Einladung von ${invitation['NameSender']}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                // Der Status wird nicht mehr angezeigt.
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => _acceptInvitation({'id': invitationId}),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _rejectInvitation({'id': invitationId}),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Freundesliste
                    const Text(
                      'Freunde',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          "Füge Freunde hinzu um diesen Modus zu spielen.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        final friend = _friends[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              friend['displayName'],
                              textAlign: TextAlign.center,
                            ),
                            trailing: ElevatedButton(
                              child: const Text('Einladen'),
                              onPressed: () => _sendInvitation(friend),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Spielverlauf
                    const Text(
                      'Spielverlauf',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadGameHistory(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text("Kein Spielverlauf vorhanden.", textAlign: TextAlign.center);
                        }
                        final history = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final game = history[index];
                            final currentUser = FirebaseAuth.instance.currentUser;
                            final isSender = currentUser != null && currentUser.uid == game["UIDSender"];
                            final myStatus = isSender ? game["StatusSender"] : game["StatusReceiver"];
                            final opponentName = isSender ? game["NameReciever"] : game["NameSender"];
                            final myScore = isSender ? game["ScoreSender"] : game["ScoreReceiver"];
                            final opponentScore = isSender ? game["ScoreReceiver"] : game["ScoreSender"];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  myStatus == "won" ? "GEWONNEN" : 
                                  myStatus == "loss" ? "VERLOREN" : 
                                  myStatus == "tie" ? "UNENTSCHIEDEN" : myStatus.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Gespielt gegen $opponentName\nScore: $myScore - $opponentScore",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}