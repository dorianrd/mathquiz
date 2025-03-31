// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseFirestore get db => _db;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Gibt das heutige Datum als String im Format YYYY-MM-DD zurück.
  String getTodayString() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  /// Holt die heutige Daily Challenge aus der Collection /daily_challenges.
  Future<Map<String, dynamic>> getTodayChallenge() async {
    final today = getTodayString();
    final docRef = _db.collection('daily_challenges').doc(today);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception("Noch keine Daily Challenge für $today angelegt!");
    }
    return snap.data() as Map<String, dynamic>;
  }

  /// Initialisiert das Benutzer-Dokument, falls noch nicht vorhanden.
  Future<void> initializeUserDocumentIfNotExists(User user) async {
    final userDocRef = _db.collection('users').doc(user.uid);
    final docSnap = await userDocRef.get();
    if (!docSnap.exists) {
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
          "gamesettings": {"difficulty": "Anfänger"},
        },
        "daily_challenge": {
          "score": 0,
          "highscore": 0,
          "gamesettings": {"difficulty": "daily"},
          "progress": {
            "done": false,
            "lastDate": "",
            "lives": 3,
            "streak": 0,
            "maxStreak": 0,
          },
        },
      };
      await userDocRef.set({
        "profile": defaultProfile,
        "settings": defaultSettings,
        "scores": defaultScores,
      }, SetOptions(merge: true));
    }
  }

  /// Gibt die UID des aktuellen Benutzers zurück.
  String? getCurrentUserId() {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // ------------------- Benutzerprofile und Einstellungen ------------------- //

  Future<Map<String, dynamic>> getUserSettings() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['settings'] ??
            {
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

  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        "settings": settings,
      }, SetOptions(merge: true));
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['profile'] ??
            {
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

  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        "profile": profileData,
      }, SetOptions(merge: true));
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  Future<String> uploadProfilePicture(File file) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("Keine angemeldeten Benutzer");
    }
    try {
      Reference ref =
          _storage.ref().child('users').child(user.uid).child('profile_picture.jpg');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print("Fehler beim Hochladen des Profilbildes: $e");
      rethrow;
    }
  }

  Future<void> updateProfilePicture(String downloadURL) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception("Keine angemeldeten Benutzer");
    try {
      await _db.collection('users').doc(user.uid).set({
        "profile": {"profilePicture": downloadURL},
      }, SetOptions(merge: true));
    } catch (e) {
      print("Fehler beim Aktualisieren des Profilbildes in Firestore: $e");
      rethrow;
    }
  }

  // ------------------- Score-Funktionen ------------------- //

  Future<void> storeScore(String mode, int score, String difficulty,
      {bool forceOverwrite = false}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Keine angemeldeten Benutzer");
    final docRef = _db.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    int? oldScore;
    int? oldHighscore;
    if (docSnap.exists && docSnap.data() != null) {
      final data = docSnap.data() as Map<String, dynamic>;
      final scores = data["scores"];
      if (scores != null &&
          scores[mode] != null &&
          scores[mode] is Map<String, dynamic>) {
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
          "gamesettings": {"difficulty": difficulty},
        },
      },
    }, SetOptions(merge: true));
  }

  Future<Map<String, Map<String, dynamic>>> getUserScores() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Keine angemeldeten Benutzer");
    final docSnap = await _db.collection('users').doc(user.uid).get();
    if (!docSnap.exists || docSnap.data() == null) return {};
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

  // ------------------- Daily Challenge Progress ------------------- //

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
          },
        },
      },
    }, SetOptions(merge: true));
  }

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

  //---------------------One-Vs-One-Spielmodus---------------------//

  /// Sendet eine Einladung für einen 1v1-Modus an einen anderen Nutzer.
  /// Sendet eine Einladung für einen 1v1-Modus an einen anderen Nutzer.
  /// Der Absender erhält dabei automatisch den Status "accepted".
  Future<String> sendOneVoneInvitation({
    required String nameSender,
    required String nameReceiver,
    required String uidSender,
    required String uidReceiver,
    String statusReceiver = 'pending',
  }) async {
    DocumentReference docRef = await _db.collection('onevone_invitations').add({
      'NameSender': nameSender,
      'NameReciever': nameReceiver,
      'UIDSender': uidSender,
      'UIDReceiver': uidReceiver,
      'TimeStamp': FieldValue.serverTimestamp(),
      'StatusSender': 'accepted', // Absenderstatus automatisch accepted
      'StatusReceiver': statusReceiver,
    });
    return docRef.id;
  }

/// Gibt einen Stream der eingehenden 1v1-Einladungen für den aktuellen Nutzer zurück.
Stream<List<Map<String, dynamic>>> getIncomingOneVoneInvitationsStream() {
  final currentUserId = getCurrentUserId();
  if (currentUserId == null) {
    throw Exception("Kein angemeldeter Benutzer");
  }
  return _db
      .collection('onevone_invitations')
      .where('UIDReceiver', isEqualTo: currentUserId)
      .where('StatusReceiver', isEqualTo: 'pending')
      .snapshots()
      .map((querySnapshot) => querySnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          }).toList());
}

    /// Gibt die eingehenden 1v1-Einladungen für den aktuellen Nutzer zurück.
  Future<List<Map<String, dynamic>>> getIncomingOneVOneInvitations() async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception("Kein angemeldeter Benutzer");
    }
    final querySnapshot = await _db
        .collection('onevone_invitations')
        .where('UIDReceiver', isEqualTo: currentUserId)
        .where('StatusReceiver', isEqualTo: 'pending')
        .get();
    List<Map<String, dynamic>> invitations = querySnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
    return invitations;
  }

  /// Akzeptiert eine 1v1-Einladung.
  Future<void> acceptOneVOneInvitation(String invitationId) async {
    await _db.collection('onevone_invitations').doc(invitationId).update({
      'StatusReceiver': 'accepted',
    });
  }

  /// Lehnt eine 1v1-Einladung ab.
  Future<void> rejectOneVOneInvitation(String invitationId) async {
    await _db.collection('onevone_invitations').doc(invitationId).update({
      'StatusReceiver': 'rejected',
    });
  }

    /// Setzt beide Statusfelder der 1v1-Einladung auf 'cancelled',
    /// um einen Abbruch für beide Spieler zu signalisieren.
    Future<void> cancelOneVoneInvitation(String invitationId) async {
      await _db.collection('onevone_invitations').doc(invitationId).update({
        'StatusSender': 'cancelled',
        'StatusReceiver': 'cancelled',
      });
    }

  // ------------------- Freundschaftsanfragen ------------------- //

  CollectionReference get _friendsCollection {
    final User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('users').doc(user.uid).collection('friends');
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  CollectionReference get _incomingFriendRequestsCollection {
    final User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('users').doc(user.uid).collection('friend_requests_incoming');
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

  CollectionReference get _outgoingFriendRequestsCollection {
    final User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('users').doc(user.uid).collection('friend_requests_outgoing');
    } else {
      throw Exception("Keine angemeldeten Benutzer");
    }
  }

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

  Future<void> acceptFriendRequest(String requesterUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");
    await _db.runTransaction((transaction) async {
      final incomingRequestRef =
          _incomingFriendRequestsCollection.doc(requesterUserId);
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
          'displayName': (requesterProfileSnap.data() as Map<String, dynamic>)['profile']
                  ['displayName'] ??
              'Unbekannt',
          'profilePicture': (requesterProfileSnap.data() as Map<String, dynamic>)['profile']
                  ['profilePicture'] ??
              '',
        },
      );
      final requesterFriendsCollection =
          _db.collection('users').doc(requesterUserId).collection('friends');
      transaction.set(
        requesterFriendsCollection.doc(currentUser.uid),
        {
          'since': FieldValue.serverTimestamp(),
          'displayName': (currentUserProfileSnap.data() as Map<String, dynamic>)['profile']
                  ['displayName'] ??
              'Unbekannt',
          'profilePicture': (currentUserProfileSnap.data() as Map<String, dynamic>)['profile']
                  ['profilePicture'] ??
              '',
        },
      );
      transaction.delete(incomingRequestRef);
      transaction.delete(outgoingRequestRef);
    });
    print("Freundschaftsanfrage von \$requesterUserId angenommen.");
  }

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
    print("Freundschaftsanfrage von \$requesterUserId abgelehnt.");
  }

  Future<void> removeFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _friendsCollection.doc(friendUid).delete();
    await _db.collection('users').doc(friendUid).collection('friends').doc(user.uid).delete();
  }

  // ------------------- Streams und Listen ------------------- //

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

  Stream<List<Map<String, dynamic>>> getIncomingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");
    return _incomingFriendRequestsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'from': doc['from'], 'timestamp': doc['timestamp']}).toList());
  }

  Stream<List<Map<String, dynamic>>> getOutgoingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Keine angemeldeten Benutzer");
    return _outgoingFriendRequestsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'to': doc['to'], 'timestamp': doc['timestamp']}).toList());
  }

  Future<List<Map<String, dynamic>>> getFriendsList() async {
    final user = FirebaseAuth.instance.currentUser;
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

  Future<Map<String, dynamic>?> getUserProfileData(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['profile'];
      } else {
        return null;
      }
    } catch (e) {
      print("Fehler beim Abrufen der Benutzerdaten: \$e");
      return null;
    }
  }

  Future<void> addFriend(String friendUid, Map<String, dynamic> friendData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _friendsCollection.doc(friendUid).set(friendData, SetOptions(merge: true));
  }

}