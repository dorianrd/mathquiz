// lib/screens/menu/modi/kopf_rechnen.dart

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
  int _lives = 3;
  int _score = 0;

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
    _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
    _loadHighScore();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

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

  void _onLevelChanged(String newLevel) {
    if (_difficultyLocked) {
      return;
    }
    setState(() {
      _selectedLevel = newLevel;
      _score = 0;
      _lives = 3;
      _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
      _answerController.clear();
      _loadHighScore();
    });
  }

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

    _lockDifficultyIfNeeded();

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

    if (_lives == 0) {
      await _handleGameOver();
      return;
    }

    _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
    _answerController.clear();
    setState(() {});
  }

  Future<void> _handleGameOver() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    // Update score and let storeScore handle highscore update.
    await firestore.storeScore(_gameMode, _score, _selectedLevel);
    if (_score > _highScore) {
      setState(() {
        _highScore = _score;
      });
    }

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
      Navigator.pop(context, _score);
    }
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _lives = 3;
      _difficultyLocked = false;
      _currentQuestion = _arithmeticsService.generateQuestion(_selectedLevel);
      _answerController.clear();
      _loadHighScore();
    });
  }

  void _showScoreDialog() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    List<Map<String, dynamic>> globalScores = [];

    try {
      globalScores = await firestore.getGlobalScores(_gameMode, _selectedLevel);
    } catch (e) {
      print("Fehler beim Laden globaler Scores: $e");
    }

    int lastScore = _score;
    await _loadHighScore();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, top: 2.0, bottom: 2.0),
                    child: Text(
                      'Highscore: $_highScore',
                      style:
                          Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, top: 2.0, bottom: 2.0),
                    child: Text(
                      'Letzter Score: $lastScore ($_selectedLevel)',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  if (globalScores.isNotEmpty)
                    ...globalScores.map((entry) {
                      final name = entry["displayName"] ?? "Unbekannt";
                      final sc = entry["score"] ?? 0;
                      final hs = entry["highscore"] ?? 0;
                      final diff = entry["gamesettings"]?["difficulty"] ?? "Unbekannt";
                      return Padding(
                        padding: const EdgeInsets.only(
                            left: 16.0, top: 2.0, bottom: 2.0),
                        child: Text(
                          "$name : $sc (Highscore: $hs) ($diff)",
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
          content: const Text(
              'Hier finden Sie hilfreiche Informationen zum Spielmodus.'),
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
    final isSelectedBeginner = _selectedLevel == 'Anfänger';
    final isSelectedAdvanced = _selectedLevel == 'Fortgeschritten';
    final isSelectedExpert = _selectedLevel == 'Experte';

    final sliderFill = _difficultyLocked
        ? Colors.deepPurple
        : Theme.of(context).colorScheme.primary;

    final borderColor = _difficultyLocked ? Colors.deepPurple : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allgemeines Kopfrechnen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final firestore =
                Provider.of<FirestoreService>(context, listen: false);
            await firestore.storeScore(_gameMode, _score, _selectedLevel);
            Navigator.pop(context, _score);
          },
        ),
        automaticallyImplyLeading: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(3, (i) {
                      if (i < _lives) {
                        return const Icon(Icons.favorite,
                            color: Colors.red, size: 28);
                      } else {
                        return const Icon(Icons.favorite_border,
                            color: Colors.red, size: 28);
                      }
                    }),
                  ),
                  InkWell(
                    onTap: _showScoreDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).brightness ==
                                Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                      ),
                      child: Text(
                        'Score: $_score',
                        style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),
              AbsorbPointer(
                absorbing: _difficultyLocked,
                child: ToggleButtons(
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
                    String lv;
                    switch (index) {
                      case 0:
                        lv = 'Anfänger';
                        break;
                      case 1:
                        lv = 'Fortgeschritten';
                        break;
                      case 2:
                        lv = 'Experte';
                        break;
                      default:
                        lv = 'Anfänger';
                        break;
                    }
                    _onLevelChanged(lv);
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text('Anfänger'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text('Fortgeschritten'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text('Experte'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _currentQuestion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
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