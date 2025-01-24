// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Basiskollektion für Freunde
  CollectionReference get _friendsCollection {
    final User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('users').doc(user.uid).collection('friends');
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  // Basiskollektion für eingehende Freundschaftsanfragen
  CollectionReference get _incomingFriendRequestsCollection {
    final User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('users').doc(user.uid).collection('friend_requests_incoming');
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  // Basiskollektion für ausgehende Freundschaftsanfragen
  CollectionReference get _outgoingFriendRequestsCollection {
    final User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('users').doc(user.uid).collection('friend_requests_outgoing');
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  /// Initialisiert ein vollständiges Benutzer-Dokument mit Profil, Einstellungen und Scores.
  /// Diese Methode sollte nach der Registrierung eines Benutzers aufgerufen werden.
  Future<void> initializeUserDocument(User user) async {
    final userDocRef = _db.collection('users').doc(user.uid);

    // Standardwerte
    final Map<String, dynamic> defaultProfile = {
      "displayName": user.displayName ?? "Neuer Benutzer",
      "email": user.email ?? "",
      "profilePicture": "",
    };

    final Map<String, dynamic> defaultSettings = {
      "notifications": true,
      "notificationsFriends": true,
      "notificationsGeneral": true,
      "theme": "light",
    };

    final Map<String, dynamic> defaultScores = {
      // Initialisiere mit leeren Scores oder Standardwerten
      // Beispiel:
      "kopf_rechnen": {
        "score": 0,
        "difficulty": "Anfänger",
      },
      // Weitere Modi können hier hinzugefügt werden
    };

    // Dokument anlegen oder mergen
    await userDocRef.set({
      "profile": defaultProfile,
      "settings": defaultSettings,
      "scores": defaultScores,
    }, SetOptions(merge: true));
  }

  /// Holt die UID des aktuellen Benutzers
  String? getCurrentUserId() {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // ------------------- Benutzerprofile und Einstellungen ------------------- //

  /// Benutzereinstellungen abrufen
  Future<Map<String, dynamic>> getUserSettings() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['settings'] ?? {
          "notifications": true,
          "notificationsFriends": true,
          "notificationsGeneral": true,
          "theme": "light",
        };
      } else {
        // Standard-Einstellungen zurückgeben, wenn keine vorhanden sind
        return {
          "notifications": true,
          "notificationsFriends": true,
          "notificationsGeneral": true,
          "theme": "light",
        };
      }
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  /// Benutzereinstellungen aktualisieren
  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set(
        {
          "settings": settings,
        },
        SetOptions(merge: true),
      );
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  /// Benutzerprofil abrufen
  Future<Map<String, dynamic>> getUserProfile() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['profile'] ?? {
          "displayName": user.displayName ?? "",
          "email": user.email ?? "",
          "profilePicture": "",
        };
      } else {
        // Standard-Profil zurückgeben, wenn kein Profil vorhanden ist
        return {
          "displayName": user.displayName ?? "",
          "email": user.email ?? "",
          "profilePicture": "",
        };
      }
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  /// Benutzerprofil aktualisieren
  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set(
        {
          "profile": profileData,
        },
        SetOptions(merge: true),
      );
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  /// Profilbild hochladen
  Future<String> uploadProfilePicture(File file) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("Keine angemeldeten Benutzer");
    }

    try {
      // Pfad: users/{uid}/profile_picture.jpg
      Reference ref = _storage.ref().child('users').child(user.uid).child('profile_picture.jpg');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print("Fehler beim Hochladen des Profilbildes: $e");
      throw e;
    }
  }

  /// Benutzerprofilbild aktualisieren
  Future<void> updateProfilePicture(String downloadURL) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("Keine angemeldeten Benutzer");
    }

    try {
      await _db.collection('users').doc(user.uid).set(
        {
          "profilePicture": downloadURL,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print("Fehler beim Aktualisieren des Profilbildes in Firestore: $e");
      throw e;
    }
  }

  // ------------------- Score-Funktionen ------------------- //

  /// Speichert den Score und die Schwierigkeit für einen bestimmten Modus (z. B. "kopf_rechnen").
  /// Überschreibt, falls bereits ein Score existiert, aber nur, wenn der neue Score höher ist
  /// oder du es erzwingen möchtest.
  Future<void> storeScore(String mode, int score, String difficulty, {bool forceOverwrite = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Keine angemeldeten Benutzer");
    }
    final docRef = _db.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    int? oldScore;
    String? oldDifficulty;
    if (docSnap.exists && docSnap.data() != null) {
      final data = docSnap.data() as Map<String, dynamic>;
      final scores = data["scores"];
      if (scores != null && scores[mode] != null) {
        if (scores[mode] is Map<String, dynamic>) {
          final modeData = scores[mode] as Map<String, dynamic>;
          oldScore = (modeData["score"] as num?)?.toInt();
          oldDifficulty = modeData["difficulty"] as String?;
        } else if (scores[mode] is int) {
          oldScore = scores[mode] as int;
          oldDifficulty = "Anfänger"; // Standard-Schwierigkeit
        }
      }
    }

    if (oldScore == null || forceOverwrite || score > oldScore) {
      // Speichere Score und Difficulty
      await docRef.set(
        {
          "scores.$mode": {
            "score": score,
            "difficulty": difficulty,
          }
        },
        SetOptions(merge: true),
      );
    }
  }

  /// Lädt die Scores für den aktuell eingeloggten User, z. B.
  /// { "kopf_rechnen": { "score": 12, "difficulty": "Fortgeschritten" }, ...}
  Future<Map<String, Map<String, dynamic>>> getUserScores() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Keine angemeldeten Benutzer");
    }
    final docSnap = await _db.collection('users').doc(user.uid).get();
    if (!docSnap.exists || docSnap.data() == null) {
      return {};
    }
    final data = docSnap.data() as Map<String, dynamic>;
    final scores = data["scores"];
    if (scores == null) return {};

    Map<String, Map<String, dynamic>> result = {};

    if (scores is Map<String, dynamic>) {
      scores.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          result[key] = value;
        } else if (value is int) {
          result[key] = {
            "score": value,
            "difficulty": "Anfänger", // Default-Schwierigkeit
          };
        }
      });
    }

    return result;
  }

  /// Lädt die globalen Scores für einen bestimmten Modus und Level (z. B. "kopf_rechnen", "Anfänger")
  /// Gibt eine Liste von { "uid": ..., "displayName": ..., "score": ..., "difficulty": ... }
  /// sortiert nach Score absteigend zurück.
  Future<List<Map<String, dynamic>>> getGlobalScores(String mode, String level) async {
    final querySnap = await _db.collection('users').get();
    // Wir gehen jeden User durch und prüfen, ob scores[mode][level] existiert.
    final List<Map<String, dynamic>> result = [];
    for (var doc in querySnap.docs) {
      final data = doc.data();
      final scores = data["scores"];
      if (scores != null && scores[mode] != null) {
        if (scores[mode] is Map<String, dynamic>) {
          final modeData = scores[mode] as Map<String, dynamic>;
          if (modeData[level] is Map<String, dynamic>) {
            final levelData = modeData[level] as Map<String, dynamic>;
            final int scoreVal = (levelData["score"] as num?)?.toInt() ?? 0;
            final String difficulty = levelData["difficulty"] ?? "Unbekannt";
            // Optional: displayName?
            String displayName = "";
            final profile = data["profile"];
            if (profile is Map) {
              displayName = profile["displayName"] ?? "Unbekannt";
            }
            result.add({
              "uid": doc.id,
              "displayName": displayName,
              "score": scoreVal,
              "difficulty": difficulty,
            });
          }
        }
      }
    }
    // Sortiere die Scores absteigend
    result.sort((a, b) => (b["score"] as int).compareTo(a["score"] as int));
    return result;
  }

// ------------------- Freundschaftsanfragen ------------------- //

  /// Sendet eine Freundschaftsanfrage von currentUser (Absender) zu targetUserId (Empfänger)
  Future<void> sendFriendRequest(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    // Verhindere das Senden an sich selbst
    if (currentUser.uid == targetUserId) {
      throw Exception("Du kannst dir nicht selbst eine Freundschaftsanfrage senden.");
    }

    // Check: Vielleicht seid ihr schon Freunde?
    final friendsDoc = await _friendsCollection.doc(targetUserId).get();
    if (friendsDoc.exists) {
      throw Exception("Dieser Benutzer ist bereits dein Freund.");
    }

    // Check: Hast du bereits eine Outgoing-Anfrage an den targetUserId?
    // Das Outgoing liegt bei dir (currentUser) in doc(targetUserId)
    final outgoingRequest = await _outgoingFriendRequestsCollection.doc(targetUserId).get();
    if (outgoingRequest.exists) {
      throw Exception("Du hast bereits eine Freundschaftsanfrage an diesen Benutzer gesendet.");
    }

    // Check: Liegt beim Empfänger (targetUserId) schon eine Incoming-Anfrage von dir (currentUser.uid)?
    final incomingRequest = await _db
        .collection('users')
        .doc(targetUserId)
        .collection('friend_requests_incoming')
        .doc(currentUser.uid)
        .get();
    if (incomingRequest.exists) {
      throw Exception("Dieser Benutzer hat dir bereits eine Freundschaftsanfrage gesendet.");
    }

    // 1) Incoming-Anfrage im Profil des Empfängers:
    //    /users/{Empfänger}/friend_requests_incoming/{Absender}
    await _db
        .collection('users')
        .doc(targetUserId)                        // EMPFÄNGER
        .collection('friend_requests_incoming')
        .doc(currentUser.uid)                     // doc(Absender)
        .set({
          'from': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

    // 2) Outgoing-Anfrage im Profil des Absenders:
    //    /users/{Absender}/friend_requests_outgoing/{Empfänger}
    await _outgoingFriendRequestsCollection.doc(targetUserId).set({
      'to': targetUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Akzeptiert eine Freundschaftsanfrage. 
  /// Param: requesterUserId = Absender der Anfrage
  Future<void> acceptFriendRequest(String requesterUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    // Empfänger = currentUser
    // Absender = requesterUserId

    // Starte Transaktion für atomare Operationen
    await _db.runTransaction((transaction) async {
      // 1) incomingRequestRef => /users/{Empfänger}/friend_requests_incoming/{Absender}
      final incomingRequestRef = _incomingFriendRequestsCollection.doc(requesterUserId);

      // 2) outgoingRequestRef => /users/{Absender}/friend_requests_outgoing/{Empfänger}
      final outgoingRequestRef = _db
          .collection('users')
          .doc(requesterUserId)
          .collection('friend_requests_outgoing')
          .doc(currentUser.uid);

      // Profile-Referenzen zum Laden der displayName/profilePicture
      final requesterProfileRef = _db.collection('users').doc(requesterUserId);
      final currentUserProfileRef = _db.collection('users').doc(currentUser.uid);

      // Hol Dokumente
      final incomingRequestSnap = await transaction.get(incomingRequestRef);
      if (!incomingRequestSnap.exists) {
        throw Exception("Freundschaftsanfrage existiert nicht.");
      }

      final requesterProfileSnap = await transaction.get(requesterProfileRef);
      final currentUserProfileSnap = await transaction.get(currentUserProfileRef);

      // Füge den Freund (Absender) in meine (Empfänger) friends-Liste
      transaction.set(
        _friendsCollection.doc(requesterUserId),
        {
          'since': FieldValue.serverTimestamp(),
          'displayName': (requesterProfileSnap.data() as Map<String, dynamic>)['profile']['displayName'] ?? 'Unbekannt',
          'profilePicture': (requesterProfileSnap.data() as Map<String, dynamic>)['profile']['profilePicture'] ?? '',
        },
      );

      // Füge mich (Empfänger) in die friends-Liste des Absenders
      final requesterFriendsCollection =
          _db.collection('users').doc(requesterUserId).collection('friends');
      transaction.set(
        requesterFriendsCollection.doc(currentUser.uid),
        {
          'since': FieldValue.serverTimestamp(),
          'displayName': (currentUserProfileSnap.data() as Map<String, dynamic>)['profile']['displayName'] ?? 'Unbekannt',
          'profilePicture': (currentUserProfileSnap.data() as Map<String, dynamic>)['profile']['profilePicture'] ?? '',
        },
      );

      // Lösche die beiden Anfrage-Dokumente
      transaction.delete(incomingRequestRef);   // incoming => /users/{Empfänger}/friend_requests_incoming/{Absender}
      transaction.delete(outgoingRequestRef);   // outgoing => /users/{Absender}/friend_requests_outgoing/{Empfänger}
    });

    print("Freundschaftsanfrage von $requesterUserId angenommen.");
  }

  /// Lehnt eine Freundschaftsanfrage von requesterUserId ab
  /// requesterUserId = Absender
  Future<void> rejectFriendRequest(String requesterUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    // Empfänger = currentUser
    // Absender = requesterUserId

    await _db.runTransaction((transaction) async {
      // incoming => /users/{Empfänger}/friend_requests_incoming/{Absender}
      final incomingRequestRef = _incomingFriendRequestsCollection.doc(requesterUserId);

      // outgoing => /users/{Absender}/friend_requests_outgoing/{Empfänger}
      final outgoingRequestRef = _db
          .collection('users')
          .doc(requesterUserId)
          .collection('friend_requests_outgoing')
          .doc(currentUser.uid);

      final incomingRequestSnap = await transaction.get(incomingRequestRef);
      if (!incomingRequestSnap.exists) {
        throw Exception("Freundschaftsanfrage existiert nicht.");
      }

      // Entferne die beiden Dokumente
      transaction.delete(incomingRequestRef);
      transaction.delete(outgoingRequestRef);
    });

    print("Freundschaftsanfrage von $requesterUserId abgelehnt.");
  }

  /// Entfernt einen Freund aus der Freundesliste
  Future<void> removeFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _friendsCollection.doc(friendUid).delete();
    // Optional: Entferne den aktuellen Benutzer auch aus der Freundesliste des anderen Benutzers
    await _db.collection('users').doc(friendUid).collection('friends').doc(user.uid).delete();
  }

  // ------------------- Streams und Listen ------------------- //

  /// Stream für die Freundesliste (Echtzeit-Updates)
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Keine angemeldeten Benutzer");

    return _friendsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          "uid": doc.id,
          "displayName": doc['displayName'] ?? "Unbekannt",
          "profilePicture": doc['profilePicture'] ?? "",
        };
      }).toList();
    });
  }

  /// Holt alle eingehenden Freundschaftsanfragen für den aktuellen Benutzer
  Stream<List<Map<String, dynamic>>> getIncomingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    return _incomingFriendRequestsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'from': doc['from'],
              'timestamp': doc['timestamp'],
            }).toList());
  }

  /// Holt alle ausgehenden Freundschaftsanfragen für den aktuellen Benutzer
  Stream<List<Map<String, dynamic>>> getOutgoingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    return _outgoingFriendRequestsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'to': doc['to'],
              'timestamp': doc['timestamp'],
            }).toList());
  }

  /// Holt die Freundesliste des aktuellen Benutzers als Future
  Future<List<Map<String, dynamic>>> getFriendsList() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final friendsSnap = await _friendsCollection.get();

    return friendsSnap.docs.map((doc) {
      final data = doc.data();
      return {
        "uid": doc.id,
        "displayName": (data as Map<String, dynamic>)["displayName"] ?? "Unbekannt",
        "profilePicture": data["profilePicture"] ?? "",
        // weitere Felder
      };
    }).toList();
  }

  /// Holt die Profil-Daten eines Benutzers anhand der UID
  Future<Map<String, dynamic>?> getUserProfileData(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['profile'];
      } else {
        return null;
      }
    } catch (e) {
      print("Fehler beim Abrufen der Benutzerdaten: $e");
      return null;
    }
  }

  /// Fügt einen Freund zur Freundesliste hinzu (intern verwendet)
  Future<void> addFriend(String friendUid, Map<String, dynamic> friendData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _friendsCollection.doc(friendUid).set(friendData, SetOptions(merge: true));
  }
}