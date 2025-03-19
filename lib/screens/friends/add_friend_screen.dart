// lib/screens/friends/add_friend_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({Key? key}) : super(key: key);

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Suche nach Nutzern mit Debounce
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(_searchController.text);
    });
  }

  /// Suche nach Nutzern anhand des eingegebenen Suchbegriffs
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('profile.displayName', isGreaterThanOrEqualTo: query)
          .where('profile.displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final currentUserId = firestore.getCurrentUserId();
      final List<Map<String, dynamic>> users = result.docs
          .where((doc) => doc.id != currentUserId) // Ausschließen des aktuellen Benutzers
          .map((doc) => {
                'uid': doc.id,
                'displayName': doc['profile']['displayName'] ?? 'Unbekannt',
                'profilePicture': doc['profile']['profilePicture'] ?? '',
              })
          .toList();

      setState(() {
        _searchResults = users;
      });
    } catch (e) {
      print("Fehler bei der Benutzersuche: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Benutzersuche: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Sendet eine Freundschaftsanfrage an einen Benutzer
  Future<void> _sendFriendRequest(String targetUserId) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.sendFriendRequest(targetUserId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Freundschaftsanfrage gesendet.')),
      );
      // Optional: Aktualisiere die Suchergebnisse, um den Button zu deaktivieren
      setState(() {
        _searchResults = _searchResults.map((user) {
          if (user['uid'] == targetUserId) {
            return {
              ...user,
              'requestSent': true,
            };
          }
          return user;
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: ${e.toString()}')),
      );
    }
  }

  /// Baut eine ListTile für jeden gefundenen Benutzer
  Widget _buildUserTile(Map<String, dynamic> user) {
    final bool requestSent = user['requestSent'] ?? false;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user['profilePicture'].isNotEmpty
            ? NetworkImage(user['profilePicture'])
            : null,
        child: user['profilePicture'].isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(user['displayName']),
      trailing: ElevatedButton(
        onPressed: requestSent ? null : () => _sendFriendRequest(user['uid']),
        style: ElevatedButton.styleFrom(
          backgroundColor: requestSent ? Colors.grey : Colors.blue,
        ),
        child: Text(requestSent ? 'Anfrage gesendet' : 'Anfrage senden'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freund hinzufügen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Suchleiste
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Suche nach Benutzern',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Suchergebnisse
            _isLoading
                ? const CircularProgressIndicator()
                : Expanded(
                    child: _searchResults.isEmpty
                        ? const Center(child: Text('Keine Ergebnisse.'))
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return _buildUserTile(user);
                            },
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}