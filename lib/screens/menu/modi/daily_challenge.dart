// lib/screens/menu/modi/daily_challenge.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/firestore_service.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({Key? key}) : super(key: key);

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  // 3 Leben pro Tag
  int _lives = 3;
  // Frage und Antwort
  String _question = "";
  String _correctAnswer = "";
  final TextEditingController _answerController = TextEditingController();

  // Aktueller Streak (score und highscore werden nicht mehr genutzt)
  int _streak = 0;

  // Flag: Hat der User die Challenge für heute bereits abgeschlossen/verloren?
  bool _doneForToday = false;

  // Statusnachricht (z. B. "-1 Leben") – wird unten angezeigt, wenn ein Leben verloren geht.
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _initDailyChallenge().then((_) {
      if (_doneForToday) {
        String resultText;
        if (_lives <= 0) {
          resultText = "Falsch! Keine Leben mehr. Streak zurückgesetzt.";
        } else {
          resultText = "Challenge bereits abgeschlossen!";
        }
        // Bei bereits abgeschlossener Challenge Popup anzeigen
        Future.delayed(Duration.zero, () {
          _showResultPopup(resultText);
        });
      }
    });
  }

  Future<void> _initDailyChallenge() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    try {
      final progress = await firestore.getDailyChallengeProgress();
      int dailyLives = progress["lives"] ?? 3;
      int dailyStreak = progress["streak"] ?? 0;
      bool dailyDone = progress["done"] ?? false;
      final String lastDate = progress["lastDate"] ?? "";
      final String today = firestore.getTodayString();

      // Reset progress, wenn ein neuer Tag begonnen hat.
      if (lastDate != today) {
        dailyLives = 3;
        dailyDone = false;
        dailyStreak = 0;
        await firestore.updateDailyChallengeProgress(
          done: false,
          lastDate: today,
          lives: dailyLives,
          streak: dailyStreak,
          maxStreak: 0, // wird nicht mehr genutzt
        );
      }

      setState(() {
        _lives = dailyLives;
        _streak = dailyStreak;
        _doneForToday = dailyDone;
      });

      final challenge = await firestore.getTodayChallenge();
      setState(() {
        _question = challenge["question"] ?? "Keine Aufgabe?";
        _correctAnswer = challenge["answer"] ?? "";
      });
    } catch (e) {
      print("Fehler beim Init DailyChallenge: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler: $e")),
      );
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  // Zeigt das Popup nur, wenn keine Leben mehr übrig sind oder die Challenge abgeschlossen ist.
  void _showResultPopup(String resultText) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resultText,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Streak: $_streak",
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Verbleibende Leben: $_lives",
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Popup schließen und zurück zum Menü navigieren
                  Navigator.pop(context); // schließt das BottomSheet
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                child: const Text("Schließen"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkAnswer() async {
    if (_doneForToday) return;

    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final answer = _answerController.text.trim();

    if (answer.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bitte Antwort eingeben.")));
      return;
    }

    bool correct = (answer == _correctAnswer);
    final String today = firestore.getTodayString();

    if (correct) {
      setState(() => _doneForToday = true);
      // Aktualisiere Streak bei richtiger Antwort
      final progress = await firestore.getDailyChallengeProgress();
      int streak = progress["streak"] ?? 0;
      streak++;
      await firestore.updateDailyChallengeProgress(
        done: true,
        lastDate: today,
        lives: _lives, // Leben bleiben bei richtiger Antwort unverändert
        streak: streak,
        maxStreak: 0, // wird nicht mehr genutzt
      );
      setState(() {
        _streak = streak;
      });
      String resultText = "Richtig! Morgen kannst du eine neue Aufgabe lösen!";
      await firestore.storeScore("daily_challenge", _streak, "daily");
      _showResultPopup(resultText);
    } else {
      // Falsche Antwort
      if (_lives > 1) {
        // Falls noch Leben übrig sind, nur ein Leben abziehen und Nachricht unten anzeigen
        setState(() {
          _lives--;
          _statusMessage = "Falsch! Leben -1.";
        });
        await firestore.updateDailyChallengeProgress(
          done: false,
          lastDate: today,
          lives: _lives,
          streak: _streak,
          maxStreak: 0,
        );
      } else {
        // Letztes Leben verloren → Challenge beenden und Popup anzeigen
        setState(() {
          _lives = 0;
          _doneForToday = true;
        });
        await firestore.updateDailyChallengeProgress(
          done: true,
          lastDate: today,
          lives: 0,
          streak: 0,
          maxStreak: 0,
        );
        setState(() {
          _streak = 0;
        });
        String resultText = "Falsch! Keine Leben mehr. Streak zurückgesetzt.";
        await firestore.storeScore("daily_challenge", _streak, "daily");
        _showResultPopup(resultText);
      }
    }

    _answerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final hearts = List.generate(3, (i) {
      return (i < _lives)
          ? const Icon(Icons.favorite, color: Colors.red, size: 28)
          : const Icon(Icons.favorite_border, color: Colors.red, size: 28);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Challenge"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _question.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: hearts),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Streak: $_streak"),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Deine Antwort",
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _doneForToday ? null : _checkAnswer,
                    child: const Text("Lösung prüfen"),
                  ),
                  const SizedBox(height: 16),
                  // Anzeige der Statusnachricht (z. B. "Falsch! Leben -1.")
                  if (_statusMessage.isNotEmpty)
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  if (_doneForToday)
                    const Text(
                      "Du bist für heute fertig. \nAb Mitternacht gibt es eine neue Aufgabe!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
    );
  }
}