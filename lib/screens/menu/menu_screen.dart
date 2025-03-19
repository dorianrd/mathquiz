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
  // KopfRechnen-Daten
  int? _lastKopfRechnenScore;
  String? _lastKopfRechnenDifficulty;

  // Daily Challenge current streak (instead of score/highscore)
  int? _dailyChallengeStreak;

  @override
  void initState() {
    super.initState();
    _loadMyScores();
  }

  Future<void> _loadMyScores() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      // KopfRechnen-Daten
      final scores = await firestore.getUserScores();
      setState(() {
        if (scores.containsKey("kopf_rechnen")) {
          _lastKopfRechnenScore = scores["kopf_rechnen"]?["score"] ?? 0;
          _lastKopfRechnenDifficulty =
              scores["kopf_rechnen"]?["gamesettings"]?["difficulty"] ?? "Anfänger";
        } else {
          _lastKopfRechnenScore = 0;
          _lastKopfRechnenDifficulty = "Anfänger";
        }
      }); 
      // Daily Challenge-Daten laden (using current streak)
      final dailyData = await firestore.getDailyChallengeProgress();
      setState(() {
        _dailyChallengeStreak = dailyData["streak"] ?? 0;
      });
    } catch (e) {
      print("Fehler beim Laden der Scores: $e");
      setState(() {
        _lastKopfRechnenScore = 0;
        _lastKopfRechnenDifficulty = "Anfänger";
        _dailyChallengeStreak = 0;
      });
    }
  }

  Future<void> _openGame(String routeName) async {
    final result = await Navigator.pushNamed(context, routeName);
    if (result is int) {
      print("Spiel beendet mit Score $result");
    }
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
        'score': _dailyChallengeStreak, // zeigt die aktuelle Streak
        'difficulty': null,
      },
      {
        'title': '1v1',
        'icon': Icons.sports_kabaddi,
        'route': '/onevone',
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

          String scoreText;
          if (mode['title'] == 'Daily Challenge') {
            scoreText = 'Aktuelle Streak: ${score ?? 0}';
          } else {
            scoreText = 'Letzter Score: ${score ?? 0}';
            if (difficulty != null) {
              scoreText += " ($difficulty)";
            }
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
                            Text(
                              scoreText,
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
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