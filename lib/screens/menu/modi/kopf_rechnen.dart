// lib/screens/kopf_rechnen/kopf_rechnen_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mathquiz/services/arithmetics_service.dart';
import 'package:mathquiz/services/firestore_service.dart';

class KopfRechnenScreen extends StatefulWidget {
  const KopfRechnenScreen({Key? key}) : super(key: key);

  @override
  State<KopfRechnenScreen> createState() => _KopfRechnenScreenState();
}

class _KopfRechnenScreenState extends State<KopfRechnenScreen> {
  final ArithmeticsService _arithmeticsService = ArithmeticsService();

  // Konstante für den Spielmodus
  final String _gameMode = "kopf_rechnen";

  // Leben und Score
  int _lives = 3; // 3 volle Herzen anfangs
  int _score = 0; // Score erhöht sich pro richtiger Antwort um 1

  // HighScore - geladen aus Firestore
  int _highScore = 0;

  String _selectedLevel = 'Anfänger';
  String _currentQuestion = '';

  // Wurde bereits gelöst? => Dann Difficulty sperren
  bool _difficultyLocked = false;

  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Erste Aufgabe generieren
    _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
    // HighScore laden
    _loadHighScore();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  // Lade den HighScore aus Firestore für das ausgewählte Level
  Future<void> _loadHighScore() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      final userScores = await firestore.getUserScores();
      setState(() {
        _highScore = userScores[_gameMode]?[_selectedLevel]?['score'] ?? 0;
      });
    } catch (e) {
      print("Fehler beim Laden des HighScores: $e");
    }
  }

  // Wechsel des Levels - solange es nicht gelockt ist
  void _onLevelChanged(String newLevel) {
    if (_difficultyLocked) {
      return; // Ignorieren, weil gesperrt
    }
    setState(() {
      _selectedLevel = newLevel;
      _score = 0; // Score zurücksetzen
      _lives = 3; // Leben zurücksetzen
      _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
      _answerController.clear();
      _loadHighScore(); // HighScore für neues Level laden
    });
  }

  // Sobald wir das erste Mal "Lösen" drücken, locken wir Difficulty
  void _lockDifficultyIfNeeded() {
    if (!_difficultyLocked) {
      setState(() {
        _difficultyLocked = true;
      });
    }
  }

  void _solveQuestion() async {
    final userAnswer = _answerController.text.trim();
    if (userAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte eine Lösung eingeben')),
      );
      return;
    }

    _lockDifficultyIfNeeded(); // 1. Mal lösen => Difficulty sperren

    final isCorrect = _arithmeticsService.checkAnswer(userAnswer);
    if (isCorrect) {
      setState(() {
        _score++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Richtig!')),
      );
    } else {
      setState(() {
        if (_lives > 0) _lives--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falsch!')),
      );
    }

    // Prüfen, ob Leben == 0 => Popup "Neustarten?" 
    if (_lives == 0) {
      await _handleGameOver();
      return; 
    }

    // Neue Aufgabe generieren
    _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
    _answerController.clear();
    setState(() {});
  }

  // Behandlung des Spielendes
  Future<void> _handleGameOver() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    // HighScore prüfen und ggf. aktualisieren
    if (_score > _highScore) {
      _highScore = _score;
      await firestore.storeScore(_gameMode, _highScore, _selectedLevel);
    } else {
      // Trotzdem den Score speichern, um den letzten Score zu aktualisieren
      await firestore.storeScore(_gameMode, _score, _selectedLevel);
    }

    // Game Over Dialog anzeigen
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Keine Leben mehr!',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Du hast $_score Punkte erreicht.\nMöchtest du neu starten?',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'menu'),
              child: const Text('Menü'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'restart'),
              child: const Text('Neustarten'),
            ),
          ],
        );
      },
    );

    if (result == 'restart') {
      _restartGame();
    } else if (result == 'menu') {
      // Zurück zum Menü und Score zurückgeben
      Navigator.pop(context, _score);
    }
  }

  // Spiel neu starten
  void _restartGame() {
    setState(() {
      _score = 0;
      _lives = 3;
      _difficultyLocked = false; // Difficulty wieder freigeben
      _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
      _answerController.clear();
      _loadHighScore(); // HighScore erneut laden
    });
  }

  // Score-Text anklickbar -> Popup mit Highscore, Lastscore und Freundesliste
  void _showScoreDialog() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    List<Map<String, dynamic>> globalScores = [];
    
    // Lade die globalen Scores der Freunde für das aktuelle Level
    try {
      globalScores = await firestore.getGlobalScores(_gameMode, _selectedLevel);
    } catch (e) {
      print("Fehler beim Laden globaler Scores: $e");
    }

    // Lade den letzten Score des Benutzers
    int lastScore = _score; // Aktueller Score als LastScore

    // Lade den HighScore des Benutzers für das aktuelle Level
    await _loadHighScore();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // Innenabstand des Inhalts
          contentPadding: const EdgeInsets.all(16.0),
          title: Text(
            'Score Übersicht',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 350, // Feste Breite des Dialogs
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // Links bündig ausrichten
                children: [
                  // Highscore anzeigen mit Einrückung
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 2.0, bottom: 2.0),
                    child: Text(
                      'Highscore: $_highScore',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Letzten Score anzeigen mit Einrückung
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 2.0, bottom: 2.0),
                    child: Text(
                      'Letzter Score: $lastScore ($_selectedLevel)',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Überschrift "Freunde-Scores" linksbündig und fett
                  Text(
                    'Freunde-Scores:',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Globale Scores anzeigen mit Einrückung
                  if (globalScores.isNotEmpty)
                    ...globalScores.map((entry) {
                      final name = entry["displayName"] ?? "Unbekannt";
                      final sc = entry["score"] ?? 0;
                      final diff = entry["difficulty"] ?? "Unbekannt";
                      return Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 2.0, bottom: 2.0),
                        child: Text(
                          "$name : $sc ($diff)",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }).toList()
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        'Keine Freunde haben gespielt.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
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

  // Hilfe-Dialog anzeigen
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Hilfe',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: const Text('Hier finden Sie hilfreiche Informationen zum Spielmodus.'),
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

  @override
  Widget build(BuildContext context) {
    // Difficulty-States
    final isSelectedBeginner = _selectedLevel == 'Anfänger';
    final isSelectedAdvanced = _selectedLevel == 'Fortgeschritten';
    final isSelectedExpert = _selectedLevel == 'Experte';

    // Farben für ToggleButtons abhängig vom Lock
    final sliderFill = _difficultyLocked 
      ? Colors.deepPurple
      : Theme.of(context).colorScheme.primary;
    
    final borderColor = _difficultyLocked
      ? Colors.deepPurple
      : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allgemeines Kopfrechnen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Zurück zum Menü und Score zurückgeben
            Navigator.pop(context, _score);
          },
        ),
        automaticallyImplyLeading: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leben + Score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 3 Herzen
                  Row(
                    children: List.generate(3, (i) {
                      if (i < _lives) {
                        return const Icon(Icons.favorite, color: Colors.red, size: 28);
                      } else {
                        return const Icon(Icons.favorite_border, color: Colors.red, size: 28);
                      }
                    }),
                  ),
                  // Score-Text -> anklickbar
                  InkWell(
                    onTap: _showScoreDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        // Leicht abgehoben, abhängig vom Theme
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800] // DarkMode => etwas helleres Dunkelgrau
                            : Colors.grey[200], // LightMode => etwas dunkleres Hellgrau
                      ),
                      child: Text(
                        'Score: $_score',
                        style: TextStyle(
                          // Textfarbe aus dem aktuellen Theme, damit es sich gut abhebt
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),

              // ToggleButtons (Difficulty)
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                selectedBorderColor: sliderFill,
                selectedColor: Colors.white,
                fillColor: sliderFill,
                borderColor: borderColor,
                isSelected: [
                  isSelectedBeginner,
                  isSelectedAdvanced,
                  isSelectedExpert,
                ],
                onPressed: (int index) {
                  if (_difficultyLocked) {
                    // gesperrt -> mach nix
                    return;
                  }
                  String lv;
                  switch (index) {
                    case 0: lv = 'Anfänger'; break;
                    case 1: lv = 'Fortgeschritten'; break;
                    case 2: lv = 'Experte'; break;
                    default: lv = 'Anfänger'; break;
                  }
                  _onLevelChanged(lv);
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Anfänger'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Fortgeschritten'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Experte'),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Aktuelle Aufgabe
              Text(
                _currentQuestion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Antwortfeld
              TextField(
                controller: _answerController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Deine Lösung',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Lösen-Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _solveQuestion,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Lösen',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // (Optional) Hilfe-Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.help_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showHelpDialog,
                    child: const Text(
                      'Hilfe?',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}