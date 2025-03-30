import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'lernlevel.dart';

class LearningModeScreen extends StatelessWidget {
  const LearningModeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lernmodus"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('learning_levels')
            .orderBy('level')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Keine Level vorhanden."));
          }
          final levels = snapshot.data!.docs;
          return ListView.builder(
            itemCount: levels.length,
            itemBuilder: (context, index) {
              final levelData = levels[index].data() as Map<String, dynamic>;
              final levelNumber = levelData['level'] ?? index + 1;
              final theme = levelData['theme'] ?? "";
              final explanation = levelData['explanation'] ?? "";
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    "Level $levelNumber - $theme",
                    textAlign: TextAlign.center,
                  ),
                  subtitle: Text(
                    explanation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearningLevelScreen(levelId: levels[index].id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}