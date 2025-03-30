import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LearningLevelScreen extends StatefulWidget {
  final String levelId;

  const LearningLevelScreen({Key? key, required this.levelId}) : super(key: key);

  @override
  _LearningLevelScreenState createState() => _LearningLevelScreenState();
}

class _LearningLevelScreenState extends State<LearningLevelScreen> {
  final TextEditingController _answerController = TextEditingController();
  bool _firstAttempt = true;
  bool _answeredCorrectly = false;
  String _feedback = "";

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _checkAnswer(Map<String, dynamic> levelData) {
    final correctAnswer = levelData['answer']?.toString().trim().toLowerCase();
    final userAnswer = _answerController.text.trim().toLowerCase();
    if (userAnswer == correctAnswer) {
      setState(() {
        _answeredCorrectly = true;
        _feedback = "Richtig!";
      });
    } else {
      if (_firstAttempt) {
        setState(() {
          _firstAttempt = false;
          _feedback = "Tipp: " + (levelData['tip'] ?? "Versuche es noch einmal.");
        });
      } else {
        setState(() {
          _feedback = "Falsch, versuche es erneut. " + (levelData['tip'] ?? "");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lernlevel"),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('learning_levels')
            .doc(widget.levelId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text("Level nicht gefunden."));
          final levelData = snapshot.data!.data() as Map<String, dynamic>;
          final levelNumber = levelData['level'] ?? "";
          final theme = levelData['theme'] ?? "";
          final explanation = levelData['explanation'] ?? "";
          final question = levelData['question'] ?? "";
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: _answeredCorrectly
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 64),
                        const SizedBox(height: 16),
                        const Text("Richtig! Weiter so.", style: TextStyle(fontSize: 24), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("Zurück"),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Level $levelNumber - $theme",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          explanation,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Frage:",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          question,
                          style: const TextStyle(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _answerController,
                          decoration: const InputDecoration(
                            labelText: "Deine Antwort",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _checkAnswer(levelData),
                          child: const Text("Antwort prüfen"),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _feedback,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}