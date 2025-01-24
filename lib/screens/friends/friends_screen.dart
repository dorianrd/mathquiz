// lib/screens/friends/friends_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import 'friend_detail_screen.dart';
import 'add_friend_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // Importiere flutter_slidable

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Eingehende Freundschaftsanfragen
  bool _hasIncomingRequests = false;
  List<Map<String, dynamic>> _incomingRequests = [];

  @override
  void initState() {
    super.initState();
    _listenForIncomingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Lauscht auf eingehende Freundschaftsanfragen und aktualisiert die Liste
  void _listenForIncomingRequests() {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    firestore.getIncomingFriendRequests().listen((requests) {
      setState(() {
        _incomingRequests = requests;
        _hasIncomingRequests = requests.isNotEmpty;
      });
    });
  }

  /// Zeigt ein Dialogfenster mit eingehenden Freundschaftsanfragen
  void _showIncomingRequestsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Freundschaftsanfragen'),
          content: _incomingRequests.isEmpty
              ? const Text('Keine neuen Anfragen.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _incomingRequests.map((request) {
                      final fromUid = request['from'];
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: Provider.of<FirestoreService>(context, listen: false)
                            .getUserProfileData(fromUid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Unbekannter Benutzer'),
                            );
                          }

                          final fromUserProfile = snapshot.data!;
                          final displayName = fromUserProfile['displayName'] ?? 'Unbekannter Benutzer';
                          final profilePic = fromUserProfile['profilePicture'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundImage: profilePic.isNotEmpty
                                      ? NetworkImage(profilePic)
                                      : null,
                                  child: profilePic.isEmpty ? const Icon(Icons.person) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName.isNotEmpty
                                            ? displayName
                                            : 'Unbekannter Benutzer',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.purple[200], // Hintergrund
                                              foregroundColor: Colors.white,     // Text/Icon-Farbe
                                            ),
                                            onPressed: () => _acceptFriendRequest(fromUid),
                                            child: const Text('Annehmen'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.purple[200],
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _rejectFriendRequest(fromUid),
                                            child: const Text('Ablehnen'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  /// Akzeptiert eine Freundschaftsanfrage
  Future<void> _acceptFriendRequest(String fromUserId) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.acceptFriendRequest(fromUserId);
      // Aktualisiere die UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Freundschaftsanfrage angenommen.')),
      );
      Navigator.pop(context); // Schließt das Dialogfenster
    } catch (e) {
      print("Fehler beim Annehmen: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Annehmen: $e')),
      );
    }
  }

  /// Lehnt eine Freundschaftsanfrage ab
  Future<void> _rejectFriendRequest(String fromUserId) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.rejectFriendRequest(fromUserId);
      // Aktualisiere die UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Freundschaftsanfrage abgelehnt.')),
      );
      Navigator.pop(context); // Schließt das Dialogfenster
    } catch (e) {
      print("Fehler beim Ablehnen: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Ablehnen: $e')),
      );
    }
  }

  /// Öffnet ein Detail-Screen für einen bestimmten Freund
  void _openFriendDetail(Map<String, dynamic> friendData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendDetailScreen(friendData: friendData),
      ),
    );
  }

  /// Navigiert zum AddFriendScreen
  void _navigateToAddFriend() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddFriendScreen(),
      ),
    );
    // Da wir Streams verwenden, ist kein explizites Aktualisieren der Liste nötig
  }

  /// Baut die Freundesliste mittels StreamBuilder (Echtzeitupdates)
  Widget _buildFriendsList() {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestore.getFriendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }
        final allFriends = snapshot.data ?? [];

        // Filtern direkt im Build ohne setState()
        final query = _searchController.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? allFriends
            : allFriends.where((f) {
                final name = (f['displayName'] ?? '').toLowerCase();
                return name.contains(query);
              }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('Keine Freunde gefunden.'));
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final friend = filtered[index];
            final displayName = friend['displayName'] ?? 'Unbekannter Freund';
            final pic = friend['profilePicture'] ?? '';

            return Slidable(
              key: Key(friend['uid']),
              endActionPane: ActionPane( // Verwende endActionPane für Swipe nach links
                motion: const ScrollMotion(),
                extentRatio: 0.20, // Angepasst, um nur den Icon-Button Platz zu geben
                children: [
                  SlidableAction(
                    onPressed: (context) => _promptRemoveFriend(friend),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.black, // Ändere die Icon-Farbe auf schwarz
                    icon: Icons.close,
                    // Entferne den 'label'-Parameter, um den Text zu entfernen
                    // label: 'Entfernen',
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      pic.isNotEmpty ? NetworkImage(pic) : null,
                  child: pic.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(displayName),
                trailing: IconButton(
                  icon: const Icon(Icons.sports_esports), // Duell-Icon
                  onPressed: () {
                    // Hier kannst du die Logik zum Einladen zu einem Duell implementieren
                    // Vorerst tut es nichts
                  },
                ),
                onTap: () => _openFriendDetail(friend),
              ),
            );
          },
        );
      },
    );
  }

  /// Zeigt einen Bestätigungsdialog zum Entfernen eines Freundes
  void _promptRemoveFriend(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Freund entfernen'),
          content: Text('Möchtest du ${friend['displayName']} wirklich entfernen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Abbrechen
              child: const Text('Nein'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Schließen des Dialogs
                await _removeFriend(friend);
              },
              child: const Text('Ja'),
            ),
          ],
        );
      },
    );
  }

  /// Entfernt einen Freund aus der Freundesliste
  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final friendName = friend['displayName'] ?? 'Unbekannter Freund';
    try {
      await firestore.removeFriend(friend['uid']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Freund $friendName entfernt.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: ${e.toString()}')),
      );
    }
  }

  /// Baut den Text für eingehende Freundschaftsanfragen
  Widget _buildIncomingRequestsText() {
    if (!_hasIncomingRequests) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: _showIncomingRequestsDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Du hast ${_incomingRequests.length} neue Freundschaftsanfragen',
          style: TextStyle(
            color: Colors.purple[300],
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kein _filterFriends() im Build → Vermeidet "setState during build" Fehler
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freunde'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Zeile: Suchfeld + AddFriend-Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Freunde suchen',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _navigateToAddFriend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[300], // Helleres Lila
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.person_add, color: Colors.white),
                ),
              ],
            ),
            // Eingehende Freundschaftsanfragen als Text unter der Suchleiste
            _buildIncomingRequestsText(),
            const SizedBox(height: 16),
            // Freundesliste
            Expanded(
              child: _buildFriendsList(),
            ),
          ],
        ),
      ),
    );
  }
}