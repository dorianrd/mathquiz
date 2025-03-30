import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class OneVOneResultWaitingScreen extends StatefulWidget {
  final String invitationId;

  const OneVOneResultWaitingScreen({Key? key, required this.invitationId}) : super(key: key);

  @override
  _OneVOneResultWaitingScreenState createState() => _OneVOneResultWaitingScreenState();
}

class _OneVOneResultWaitingScreenState extends State<OneVOneResultWaitingScreen> {
  bool _resultsCalculated = false;
  String _senderResult = "";
  String _receiverResult = "";
  int _scoreSender = 0;
  int _scoreReceiver = 0;

  Future<void> _calculateResults(DocumentSnapshot<Map<String, dynamic>> snapshot) async {
    final data = snapshot.data();
    if (data == null || !data.containsKey("gameData")) return;
    final gameData = data["gameData"] as Map<String, dynamic>;
    final correctAnswers = List<String>.from(gameData["correctAnswers"] ?? []);
    final playerAnswers = gameData["playerAnswers"] as Map<String, dynamic>? ?? {};

    int scoreSender = 0;
    int scoreReceiver = 0;

    playerAnswers.forEach((uid, answersList) {
      List<dynamic> answers = answersList;
      int score = 0;
      for (int i = 0; i < correctAnswers.length; i++) {
        if (i < answers.length && answers[i] == correctAnswers[i]) {
          score += 10;
        }
      }
      if (uid == data["UIDSender"]) {
        scoreSender = score;
      } else if (uid == data["UIDReceiver"]) {
        scoreReceiver = score;
      }
    });

    String senderResult;
    String receiverResult;
    if (scoreSender > scoreReceiver) {
      senderResult = "won";
      receiverResult = "loss";
    } else if (scoreSender < scoreReceiver) {
      senderResult = "loss";
      receiverResult = "won";
    } else {
      senderResult = "tie";
      receiverResult = "tie";
    }

    // Speichere die berechneten Scores und Status in Firestore
    await FirebaseFirestore.instance
        .collection('onevone_invitations')
        .doc(widget.invitationId)
        .update({
      "ScoreSender": scoreSender,
      "ScoreReceiver": scoreReceiver,
      "StatusSender": senderResult,
      "StatusReceiver": receiverResult,
    });

    if (mounted) {
      setState(() {
        _resultsCalculated = true;
        _scoreSender = scoreSender;
        _scoreReceiver = scoreReceiver;
        _senderResult = senderResult;
        _receiverResult = receiverResult;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ergebnis auswerten"),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('onevone_invitations')
            .doc(widget.invitationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Einladung existiert nicht."));
          }
          final data = snapshot.data!.data();
          if (data == null) return const Center(child: Text("Keine Daten verfügbar."));

          // Prüfung, ob beide Spieler fertig sind (finished, won, loss oder tie)
          final senderStatus = data["StatusSender"].toString().toLowerCase();
          final receiverStatus = data["StatusReceiver"].toString().toLowerCase();
          if ((["finished", "won", "loss", "tie"].contains(senderStatus)) &&
              (["finished", "won", "loss", "tie"].contains(receiverStatus))) {
            if (!_resultsCalculated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _calculateResults(snapshot.data!);
              });
            }
            final currentUser = FirebaseAuth.instance.currentUser;
            final bool isSender = currentUser != null && currentUser.uid == data["UIDSender"];
            final myScore = isSender ? _scoreSender : _scoreReceiver;
            final opponentScore = isSender ? _scoreReceiver : _scoreSender;
            final myResult = isSender ? _senderResult : _receiverResult;
            final myName = isSender ? data["NameSender"] : data["NameReciever"];
            final opponentName = isSender ? data["NameReciever"] : data["NameSender"];

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      myResult == "won"
                          ? "Gewonnen!"
                          : myResult == "loss"
                              ? "Verloren!"
                              : "Unentschieden!",
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "$myName: $myScore Punkte",
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$opponentName: $opponentScore Punkte",
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                      },
                      child: const Text("Zum Menü", style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(
              child: Text(
                "Warte auf den anderen Spieler...",
                textAlign: TextAlign.center,
              ),
            );
          }
        },
      ),
    );
  }
}