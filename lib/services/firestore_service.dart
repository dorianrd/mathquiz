// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Gibt das heutige Datum als String im Format YYYY-MM-DD zurück
  String getTodayString() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-"
           "${now.month.toString().padLeft(2, '0')}-"
           "${now.day.toString().padLeft(2, '0')}";
  }

  /// Holt die heutige Challenge (Frage, Antwort, etc.) aus /daily_challenges/{Heute}
  Future<Map<String, dynamic>> getTodayChallenge() async {
    final today = getTodayString();
    final docRef = _db.collection('daily_challenges').doc(today);
    final snap = await docRef.get();

    if (!snap.exists) {
      throw Exception("Noch keine Daily Challenge für $today angelegt!");
    }
    return snap.data() as Map<String, dynamic>;
  }

  /// Initialisiert das Benutzer-Dokument **nur**, wenn es noch nicht existiert.
  /// So werden bestehende Scores/Streaks nicht bei jedem Login überschrieben.
  Future<void> initializeUserDocumentIfNotExists(User user) async {
    final userDocRef = _db.collection('users').doc(user.uid);
    final docSnap = await userDocRef.get();

    // Nur Standardwerte setzen, falls das Dokument noch nicht existiert
    if (!docSnap.exists) {
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
        "kopf_rechnen": {
          "score": 0,
          "highscore": 0,
          "gamesettings": {
            "difficulty": "Anfänger",
          },
        },
        "daily_challenge": {
          "score": 0,
          "highscore": 0,
          "gamesettings": {
            "difficulty": "daily",
          },
          // Daily progress data wird hier gespeichert.
          "progress": {
            "done": false,
            "lastDate": "",
            "lives": 3,
            "streak": 0,
            "maxStreak": 0,
          }
        },
        // Weitere Modi können hier hinzugefügt werden
      };

      // Dokument anlegen
      await userDocRef.set({
        "profile": defaultProfile,
        "settings": defaultSettings,
        "scores": defaultScores,
      }, SetOptions(merge: true));
    }
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
    if (user == null) throw Exception("Keine angemeldeten Benutzer");

    try {
      // Aktualisiere den profile-Teil des Dokuments
      await _db.collection('users').doc(user.uid).set({
        "profile": {
          "profilePicture": downloadURL,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print("Fehler beim Aktualisieren des Profilbildes in Firestore: $e");
      throw e;
    }
  }

  // ------------------- Score-Funktionen ------------------- //

  /// Speichert den Score und die Schwierigkeit für einen bestimmten Modus
  /// unter dem Pfad: users/{user}/scores/{mode} -> { score, highscore, gamesettings: { difficulty } }
  Future<void> storeScore(String mode, int score, String difficulty, {bool forceOverwrite = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Keine angemeldeten Benutzer");
    }
    final docRef = _db.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    int? oldScore;
    int? oldHighscore;
    if (docSnap.exists && docSnap.data() != null) {
      final data = docSnap.data() as Map<String, dynamic>;
      final scores = data["scores"];
      if (scores != null && scores[mode] != null && scores[mode] is Map<String, dynamic>) {
        final modeData = scores[mode] as Map<String, dynamic>;
        oldScore = (modeData["score"] as num?)?.toInt();
        oldHighscore = (modeData["highscore"] as num?)?.toInt();
      }
    }

    int newHighscore = (oldHighscore ?? 0) < score ? score : (oldHighscore ?? 0);

    await docRef.set({
      "scores": {
        mode: {
          "score": score,
          "highscore": newHighscore,
          "gamesettings": {
            "difficulty": difficulty,
          },
        },
      },
    }, SetOptions(merge: true));
  }

  /// Lädt die Scores für den aktuell eingeloggten User.
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
        }
      });
    }

    return result;
  }

  /// Lädt die globalen Scores für einen bestimmten Modus und Level.
  Future<List<Map<String, dynamic>>> getGlobalScores(String mode, String level) async {
    final querySnap = await _db.collection('users').get();
    final List<Map<String, dynamic>> result = [];
    for (var doc in querySnap.docs) {
      final data = doc.data();
      final scores = data["scores"];
      if (scores != null && scores[mode] != null) {
        if (scores[mode] is Map<String, dynamic>) {
          final modeData = scores[mode] as Map<String, dynamic>;
          if (modeData["gamesettings"] != null && modeData["gamesettings"]["difficulty"] == level) {
            final int scoreVal = (modeData["score"] as num?)?.toInt() ?? 0;
            final int highscoreVal = (modeData["highscore"] as num?)?.toInt() ?? 0;
            String displayName = "";
            final profile = data["profile"];
            if (profile is Map) {
              displayName = profile["displayName"] ?? "Unbekannt";
            }
            result.add({
              "uid": doc.id,
              "displayName": displayName,
              "score": scoreVal,
              "highscore": highscoreVal,
              "gamesettings": modeData["gamesettings"],
            });
          }
        }
      }
    }
    result.sort((a, b) => (b["score"] as int).compareTo(a["score"] as int));
    return result;
  }

  // ------------------- Neue Methoden für Daily Challenge Progress ------------------- //

  /// Aktualisiert die Daily Challenge Fortschrittsdaten unter
  /// users/{user}/scores/daily_challenge/progress
  Future<void> updateDailyChallengeProgress({
    required bool done,
    required String lastDate,
    required int lives,
    required int streak,
    required int maxStreak,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Keine angemeldeten Benutzer");
    await _db.collection('users').doc(user.uid).set({
      "scores": {
        "daily_challenge": {
          "progress": {
            "done": done,
            "lastDate": lastDate,
            "lives": lives,
            "streak": streak,
            "maxStreak": maxStreak,
          }
        }
      }
    }, SetOptions(merge: true));
  }

  /// Liest die Daily Challenge Fortschrittsdaten aus
  /// users/{user}/scores/daily_challenge/progress
  Future<Map<String, dynamic>> getDailyChallengeProgress() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Keine angemeldeten Benutzer");
    final docSnap = await _db.collection('users').doc(user.uid).get();
    if (!docSnap.exists || docSnap.data() == null) return {};
    final data = docSnap.data() as Map<String, dynamic>;
    final scores = data["scores"];
    if (scores != null &&
        scores["daily_challenge"] != null &&
        scores["daily_challenge"] is Map<String, dynamic>) {
      final dailyChallenge = scores["daily_challenge"] as Map<String, dynamic>;
      return dailyChallenge["progress"] as Map<String, dynamic>? ?? {};
    }
    return {};
  }

  // ------------------- Freundschaftsanfragen ------------------- //

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

  /// Sendet eine Freundschaftsanfrage von currentUser zu targetUserId.
  Future<void> sendFriendRequest(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    if (currentUser.uid == targetUserId) {
      throw Exception("Du kannst dir nicht selbst eine Freundschaftsanfrage senden.");
    }

    final friendsDoc = await _friendsCollection.doc(targetUserId).get();
    if (friendsDoc.exists) {
      throw Exception("Dieser Benutzer ist bereits dein Freund.");
    }

    final outgoingRequest = await _outgoingFriendRequestsCollection.doc(targetUserId).get();
    if (outgoingRequest.exists) {
      throw Exception("Du hast bereits eine Freundschaftsanfrage an diesen Benutzer gesendet.");
    }

    final incomingRequest = await _db
        .collection('users')
        .doc(targetUserId)
        .collection('friend_requests_incoming')
        .doc(currentUser.uid)
        .get();
    if (incomingRequest.exists) {
      throw Exception("Dieser Benutzer hat dir bereits eine Freundschaftsanfrage gesendet.");
    }

    await _db
        .collection('users')
        .doc(targetUserId)
        .collection('friend_requests_incoming')
        .doc(currentUser.uid)
        .set({
          'from': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

    await _outgoingFriendRequestsCollection.doc(targetUserId).set({
      'to': targetUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Akzeptiert eine Freundschaftsanfrage.
  Future<void> acceptFriendRequest(String requesterUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    await _db.runTransaction((transaction) async {
      final incomingRequestRef = _incomingFriendRequestsCollection.doc(requesterUserId);
      final outgoingRequestRef = _db
          .collection('users')
          .doc(requesterUserId)
          .collection('friend_requests_outgoing')
          .doc(currentUser.uid);

      final requesterProfileRef = _db.collection('users').doc(requesterUserId);
      final currentUserProfileRef = _db.collection('users').doc(currentUser.uid);

      final incomingRequestSnap = await transaction.get(incomingRequestRef);
      if (!incomingRequestSnap.exists) {
        throw Exception("Freundschaftsanfrage existiert nicht.");
      }

      final requesterProfileSnap = await transaction.get(requesterProfileRef);
      final currentUserProfileSnap = await transaction.get(currentUserProfileRef);

      transaction.set(
        _friendsCollection.doc(requesterUserId),
        {
          'since': FieldValue.serverTimestamp(),
          'displayName': (requesterProfileSnap.data() as Map<String, dynamic>)['profile']['displayName'] ?? 'Unbekannt',
          'profilePicture': (requesterProfileSnap.data() as Map<String, dynamic>)['profile']['profilePicture'] ?? '',
        },
      );

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

      transaction.delete(incomingRequestRef);
      transaction.delete(outgoingRequestRef);
    });

    print("Freundschaftsanfrage von $requesterUserId angenommen.");
  }

  /// Lehnt eine Freundschaftsanfrage ab.
  Future<void> rejectFriendRequest(String requesterUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");

    await _db.runTransaction((transaction) async {
      final incomingRequestRef = _incomingFriendRequestsCollection.doc(requesterUserId);
      final outgoingRequestRef = _db
          .collection('users')
          .doc(requesterUserId)
          .collection('friend_requests_outgoing')
          .doc(currentUser.uid);

      final incomingRequestSnap = await transaction.get(incomingRequestRef);
      if (!incomingRequestSnap.exists) {
        throw Exception("Freundschaftsanfrage existiert nicht.");
      }

      transaction.delete(incomingRequestRef);
      transaction.delete(outgoingRequestRef);
    });

    print("Freundschaftsanfrage von $requesterUserId abgelehnt.");
  }

  /// Entfernt einen Freund aus der Freundesliste.
  Future<void> removeFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _friendsCollection.doc(friendUid).delete();
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