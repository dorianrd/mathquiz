// lib/screens/menu/modi/onevone/onevone_game_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mathquiz/services/firestore_service.dart';

class OneVOneGameScreen extends StatefulWidget {
  final Map<String, dynamic> invitation;
  const OneVOneGameScreen({Key? key, required this.invitation}) : super(key: key);

  @override
  State<OneVOneGameScreen> createState() => _OneVOneGameScreenState();
}

class _OneVOneGameScreenState extends State<OneVOneGameScreen> {
  int _lives = 3;
  int _score = 0;
  int _currentRound = 1;
  final int _maxRounds = 3;
  final int _questionsPerRound = 3;
  int _currentQuestionIndex = 0;
  String _currentQuestion = "Frage wird geladen...";
  final TextEditingController _answerController = TextEditingController();
  bool _gameEnded = false;

  @override
  void initState() {
    super.initState();
    _loadNewQuestion();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _loadNewQuestion() {
    // Simuliere eine Dummyfrage; in einer echten App lädst du hier die Frage.
    setState(() {
      _currentQuestion = "Was ist ${_currentRound + _currentQuestionIndex}?";
      _answerController.clear();
    });
  }

  void _submitAnswer() {
    String answer = _answerController.text.trim();
    // Dummy-Überprüfung: Richtige Antwort ist "42"
    bool correct = answer == "42";
    setState(() {
      if (correct) {
        _score += 10;
      } else {
        _lives -= 1;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(correct ? "Richtig!" : "Falsch!")),
    );
    _nextStep();
  }

  void _nextStep() {
    // Spiel beenden, wenn keine Leben mehr vorhanden sind oder alle Runden gespielt wurden.
    if (_lives <= 0 || _currentRound > _maxRounds) {
      _endGame(canceled: false);
      return;
    }
    if (_currentQuestionIndex < _questionsPerRound - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _loadNewQuestion();
    } else {
      setState(() {
        _currentRound++;
        _currentQuestionIndex = 0;
      });
      _loadNewQuestion();
    }
  }

  /// Beendet das Spiel.
  /// Falls canceled true ist, wird der Score auf 0 gesetzt und das Ergebnis als "Verloren" markiert.
  Future<void> _endGame({required bool canceled}) async {
    if (_gameEnded) return;
    setState(() {
      _gameEnded = true;
    });
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final invitationId = widget.invitation['id'];
    final user = FirebaseAuth.instance.currentUser;
    
    // Bei Spielabbruch: Score auf 0 setzen.
    if (canceled) {
      _score = 0;
    }
    
    // Beispiel-Logik: Wenn nicht abgebrochen und Score > 0, dann "Gewonnen", sonst "Verloren"
    String result = (!canceled && _score > 0) ? "Won" : "Loss";
    
    // Setze den Status der Einladung auf "abgeschlossen"
    await firestore.db.collection('onevone_invitations')
      .doc(invitationId)
      .update({'status': 'abgeschlossen'});
      
    // Speichere das Spielergebnis im Nutzerprofil (users -> (user) -> scores -> onevone -> history -> (gameId))
    if (user != null) {
      await firestore.db.collection('users').doc(user.uid).set({
        "scores": {
          "onevone": {
            "history": {
              invitationId: {
                "state": result,
                "score": _score,
                "leftLives": _lives,
                "timestamp": FieldValue.serverTimestamp(),
              }
            }
          }
        }
      }, SetOptions(merge: true));
    }
    
    // Zeige Ergebnisdialog und navigiere zurück ins Menü.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Spiel beendet"),
        content: Text("Runden: $_currentRound\nScore: $_score\nLeben: $_lives\nErgebnis: $result"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog schließen
              Navigator.pop(context); // Zurück zum Menü
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Bricht das Spiel ab.
  Future<void> _cancelGame() async {
    // Hier ggf. Bestätigung einfügen
    await _endGame(canceled: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Spiel – Runde $_currentRound"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Oben: Leben (links) und Score (rechts)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Leben: $_lives", style: const TextStyle(fontSize: 18)),
                Text("Score: $_score", style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 30),
            // Mittig: Aktuelle Frage
            Text(
              _currentQuestion,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Antwortfeld
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: "Antwort eingeben",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            // Button zum Antwort absenden
            ElevatedButton(
              onPressed: _submitAnswer,
              child: const Text("Antwort absenden"),
            ),
            const SizedBox(height: 20),
            // Button zum Spiel abbrechen
            ElevatedButton(
              onPressed: _cancelGame,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Spiel abbrechen"),
            ),
          ],
        ),
      ),
    );
  }
}