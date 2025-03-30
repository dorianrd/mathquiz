import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/firestore_service.dart';

// Füge ganz oben in der Datei hinzu (bei den anderen Imports)
import 'onevone_game.dart';

class OneVOneWaitingScreen extends StatefulWidget {
  final String invitationId;

  const OneVOneWaitingScreen({Key? key, required this.invitationId}) : super(key: key);

  @override
  _OneVOneWaitingScreenState createState() => _OneVOneWaitingScreenState();
}
// Innerhalb der State-Klasse _OneVOneWaitingScreenState, füge folgende Zeile ein:
class _OneVOneWaitingScreenState extends State<OneVOneWaitingScreen> {
  bool _hasNavigated = false; // Neu: Flag, um doppelte Navigation zu vermeiden.
  
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Wartezimmer'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: firestoreService.db
                            .collection('onevone_invitations')
                            .doc(widget.invitationId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return Center(
                              child: Text(
                                "Einladung wurde abgebrochen.",
                                style: TextStyle(fontSize: 16, color: Colors.black),
                              ),
                            );
                          }
                          final data = snapshot.data!.data();
                          if (data == null) {
                            return Center(
                              child: Text(
                                "Einladung konnte nicht geladen werden.",
                                style: TextStyle(fontSize: 16, color: Colors.black),
                              ),
                            );
                          }
                          // Debug-Ausgabe in der Konsole
                          print("Firestore data: $data");

                          if (data['StatusSender'] == 'cancelled' ||
                              data['StatusReceiver'] == 'cancelled' ||
                              data['StatusReceiver'] == 'rejected') {
                            Future.microtask(() {
                              Navigator.pop(context);
                            });
                            return SizedBox();
                          }
                          
                          // Prüfen, ob beide Spieler akzeptiert haben
                          bool bothAccepted = (data['StatusSender'] == 'accepted') &&
                              (data['StatusReceiver'] == 'accepted');

                          // Falls beide Spieler akzeptiert haben, starte die Navigation in den Spielbildschirm
                          if (bothAccepted && !_hasNavigated) {
                            _hasNavigated = true;
                            Future.delayed(Duration(seconds: 1), () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OneVOneGameScreen(invitationId: widget.invitationId),
                                ),
                              );
                            });
                          }
                          
                          return Center(
                            child: bothAccepted
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Beide Spieler haben akzeptiert.",
                                        style: TextStyle(fontSize: 18, color: Colors.green),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        "Warte auf Spielstart...",
                                        style: TextStyle(fontSize: 18, color: Colors.green),
                                      ),
                                    ],
                                  )
                                : Text(
                                    "Warte auf Akzeptanz durch beide Spieler...\n\nStatusSender: ${data['StatusSender']}\nStatusReceiver: ${data['StatusReceiver']}",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.black),
                                  ),
                          );
                        },
                      ),
                      SizedBox(height: 32),
                      // Cancel-Button bleibt hier am Ende des Inhalts
                      ElevatedButton.icon(
                        onPressed: () async {
                          await firestoreService.cancelOneVoneInvitation(widget.invitationId);
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.cancel),
                        label: Text('Abbrechen', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}