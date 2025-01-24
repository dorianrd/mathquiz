// lib/screens/menu/menu_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mathquiz/services/firestore_service.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // Speichern wir den zuletzt erzielten Score und Schwierigkeit für den Modus KopfRechnen
  int? _lastKopfRechnenScore;
  String? _lastKopfRechnenDifficulty;

  @override
  void initState() {
    super.initState();
    _loadMyScores();
  }

  Future<void> _loadMyScores() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      final scores = await firestore.getUserScores();
      setState(() {
        if (scores.containsKey("kopf_rechnen")) {
          _lastKopfRechnenScore = scores["kopf_rechnen"]?["score"] ?? 0;
          _lastKopfRechnenDifficulty = scores["kopf_rechnen"]?["difficulty"] ?? "Anfänger";
        } else {
          _lastKopfRechnenScore = 0;
          _lastKopfRechnenDifficulty = "Anfänger"; // Standard-Difficulty
        }
      });
    } catch (e) {
      print("Fehler beim Laden der Scores: $e");
      setState(() {
        _lastKopfRechnenScore = 0;
        _lastKopfRechnenDifficulty = "Anfänger";
      });
    }
  }

  // Wenn wir vom KopfRechnenScreen zurückkehren (z. B. per Navigator.pop),
  // können wir hier den Score direkt übernehmen ODER wir laden neu aus DB:
  // -> Hier zeigen wir eine Variante, in der wir "result" abfragen.
  // -> Dann aber kannst du optional nochmal _loadMyScores() aufrufen, um DB zu syncen
  Future<void> _openGame(String routeName) async {
    final result = await Navigator.pushNamed(context, routeName);
    if (result is int) {
      // Der Score, den wir aus KopfRechnenScreen kriegen.
      // Optional: Hier kannst du FirestoreService.storeScore(...) aufrufen,
      // falls du den Score manuell speichern möchtest. Aber im KopfRechnenScreen
      // wird der Score bereits gespeichert, wenn das Spiel endet.
      print("Spiel beendet mit Score $result");
    }
    // Anschließend neu laden
    await _loadMyScores();
  }

  @override
  Widget build(BuildContext context) {
    final modes = [
      {
        'title': 'Allgemeines Kopfrechnen',
        'icon': Icons.calculate,
        'route': '/kopf_rechnen',
        'score': _lastKopfRechnenScore,
        'difficulty': _lastKopfRechnenDifficulty,
      },
      {
        'title': 'Daily Challenge',
        'icon': Icons.calendar_today,
        'route': '/daily_challenge',
        'score': null,
        'difficulty': null,
      },
      {
        'title': '1v1',
        'icon': Icons.sports_kabaddi,
        'route': '/1v1',
        'score': null,
        'difficulty': null,
      },
      {
        'title': 'Lernen',
        'icon': Icons.school,
        'route': '/lernen',
        'score': null,
        'difficulty': null,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Math Quiz Menü'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: modes.length,
        itemBuilder: (context, index) {
          final mode = modes[index];
          final routeName = mode['route'] as String?;
          final score = mode['score'];
          final difficulty = mode['difficulty'];

          String scoreText = 'Letzter Score: 0 (Anfänger)';
          if (score != null && difficulty != null) {
            scoreText = 'Letzter Score: $score ($difficulty)';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            elevation: 3,
            child: InkWell(
              onTap: () async {
                if (routeName != null) {
                  await _openGame(routeName);
                }
              },
              child: SizedBox(
                height: 100,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(mode['icon'] as IconData, size: 40),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode['title'] as String,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            // Letzter Score mit Difficulty anzeigen
                            Text(
                              score != null && difficulty != null
                                  ? 'Letzter Score: $score ($difficulty)'
                                  : 'Letzter Score: 0 (Anfänger)',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}