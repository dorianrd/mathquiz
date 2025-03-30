import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/arithmetics_service.dart';
import 'onevone_result_waiting.dart'; // Neuer Result Waiting Screen

class OneVOneGameScreen extends StatefulWidget {
  final String invitationId;

  const OneVOneGameScreen({Key? key, required this.invitationId}) : super(key: key);

  @override
  _OneVOneGameScreenState createState() => _OneVOneGameScreenState();
}

class _OneVOneGameScreenState extends State<OneVOneGameScreen> {
  List<String> _questions = [];
  List<String> _correctAnswers = [];
  int _currentQuestionIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  bool _isLoading = true;
  bool _gameInitialized = false;

  final int _numQuestions = 5;
  int _lives = 3;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  /// Initialisiert das Spiel:
  /// Falls im Einladung-Dokument noch kein "gameData" existiert, werden _numQuestions Fragen
  /// (auf dem Level "Fortgeschritten") generiert, die korrekten Antworten sowie leere Antwort-Arrays
  /// für beide Spieler erstellt und zusammen mit dem Status "ongoing" im Dokument gespeichert.
  /// Anschließend werden die Top-Level-Felder StatusSender und StatusReceiver auf "ongoing" gesetzt.
  Future<void> _initializeGame() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final docRef = firestoreService.db.collection('onevone_invitations').doc(widget.invitationId);

    await firestoreService.db.runTransaction((transaction) async {
      final docSnap = await transaction.get(docRef);
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data.containsKey("gameData")) {
          // Falls bereits Spiel-Daten existieren, nutze diese
          final gameData = data["gameData"] as Map<String, dynamic>;
          _questions = List<String>.from(gameData["questions"] ?? []);
          _correctAnswers = List<String>.from(gameData["correctAnswers"] ?? []);
          transaction.update(docRef, {
            "StatusSender": "ongoing",
            "StatusReceiver": "ongoing",
          });
          return;
        } else {
          // Generiere Fragen nur einmal:
          final arithmetics = ArithmeticsService();
          List<String> questions = [];
          List<String> answers = [];
          for (int i = 0; i < _numQuestions; i++) {
            final question = arithmetics.generateQuestion("Fortgeschritten");
            final answer = arithmetics.getLastResult.toString();
            questions.add(question);
            answers.add(answer);
          }
          // Hole die UIDs der Spieler aus dem Dokument
          final docData = data as Map<String, dynamic>;
          final String uidSender = docData["UIDSender"];
          final String uidReceiver = docData["UIDReceiver"];
          // Erstelle leere Antwort-Arrays für beide Spieler
          final Map<String, dynamic> playerAnswers = {
            uidSender: List<String>.filled(_numQuestions, ""),
            uidReceiver: List<String>.filled(_numQuestions, ""),
          };
          final gameData = {
            "questions": questions,
            "correctAnswers": answers,
            "playerAnswers": playerAnswers,
          };
          transaction.update(docRef, {
            "gameData": gameData,
            "StatusSender": "ongoing",
            "StatusReceiver": "ongoing",
          });
          _questions = questions;
          _correctAnswers = answers;
        }
      }
    });

    setState(() {
      _gameInitialized = true;
      _isLoading = false;
    });
  }

  /// Aktualisiert nur den Status des aktuellen Spielers (Sender oder Receiver) auf "finished".
  Future<void> _finishGameForCurrentUser(DocumentReference docRef, Map<String, dynamic> docData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    String fieldToUpdate = "";
    if (currentUser.uid == docData["UIDSender"]) {
      fieldToUpdate = "StatusSender";
    } else {
      fieldToUpdate = "StatusReceiver";
    }
    await docRef.update({fieldToUpdate: "finished"});
  }

  /// Speichert die Antwort des aktuellen Spielers für die aktuelle Frage.
  /// Bei korrekter Antwort wird der Score um 10 erhöht, bei falscher Antwort ein Leben abgezogen.
  /// Sobald keine Leben mehr übrig sind oder alle Fragen beantwortet wurden,
  /// wird nur der Status des aktuellen Spielers auf "finished" gesetzt und der Spieler gelangt in den Wartebildschirm.
  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final docRef = firestoreService.db.collection('onevone_invitations').doc(widget.invitationId);

    // Hole das aktuelle Dokument, um die UIDs zu bestimmen.
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;
    final docData = docSnap.data();
    if (docData == null) return;

    // Prüfe, ob die Antwort korrekt ist.
    bool isCorrect = (answer == _correctAnswers[_currentQuestionIndex]);

    if (isCorrect) {
      _score += 10;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Richtig! +10 Punkte')),
      );
    } else {
      _lives--;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falsch!')),
      );
      if (_lives <= 0) {
        // Keine Leben mehr: Aktualisiere nur den Status des aktuellen Spielers auf "finished" und gehe in den Wartebildschirm.
        await _finishGameForCurrentUser(docRef, docData);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OneVOneResultWaitingScreen(invitationId: widget.invitationId),
          ),
        );
        return;
      }
    }

    // Hole das aktuelle gameData und speichere die Antwort des Spielers.
    final docSnapUpdated = await docRef.get();
    if (!docSnapUpdated.exists) return;
    final data = docSnapUpdated.data();
    if (data == null || !data.containsKey("gameData")) return;

    Map<String, dynamic> gameData = Map<String, dynamic>.from(data["gameData"]);
    Map<String, dynamic> playerAnswers = Map<String, dynamic>.from(gameData["playerAnswers"] ?? {});
    List<dynamic> answersArray = List<dynamic>.from(playerAnswers[currentUser.uid] ?? List.filled(_numQuestions, ""));
    answersArray[_currentQuestionIndex] = answer;
    playerAnswers[currentUser.uid] = answersArray;
    gameData["playerAnswers"] = playerAnswers;

    await docRef.update({"gameData": gameData});

    _answerController.clear();
    setState(() {
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        // Alle Fragen beantwortet: Aktualisiere nur den Status des aktuellen Spielers und navigiere in den Wartebildschirm.
        _finishGameForCurrentUser(docRef, docData).then((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OneVOneResultWaitingScreen(invitationId: widget.invitationId),
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("1v1 Spiel")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("1v1 Spiel"),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // Darstellung der Leben als Herzen (3 max)
                Row(
                  children: List.generate(3, (index) {
                    return Icon(
                      index < _lives ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                    );
                  }),
                ),
                Spacer(),
                // Anzeige des aktuellen Scores
                Text("Score: $_score", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _gameInitialized
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Frage ${_currentQuestionIndex + 1} von ${_questions.length}",
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 20),
                    Text(
                      _questions[_currentQuestionIndex],
                      style: TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _answerController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Deine Antwort",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitAnswer,
                      child: Text("Antwort absenden"),
                    ),
                  ],
                )
              : Center(child: Text("Spiel wird initialisiert...")),
        ),
      ),
    );
  }
}