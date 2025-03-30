// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onGameUpdate = functions.firestore
  .document('onevone_games/{gameId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const gameId = context.params.gameId;
    let updateData = {};

    // Beispiel: Wenn Invitee von "pending" auf "accepted" wechselt
    if (before.inviteeStatus === 'pending' && after.inviteeStatus === 'accepted') {
      updateData.toStatus = 'accepted';
      updateData.fromStatus = 'accepted';
    }

    // Wenn beide Spieler "ready" sind, setze beide auf "ingame"
    if (
      after.inviterStatus === 'ready' &&
      after.inviteeStatus === 'ready' &&
      (before.inviterStatus !== 'ingame' || before.inviteeStatus !== 'ingame')
    ) {
      updateData.inviterStatus = 'ingame';
      updateData.inviteeStatus = 'ingame';
    }

    // Wenn einer das Spiel abbricht (finished), soll das Spiel sofort beendet werden
    if (after.inviterStatus === 'finished' || after.inviteeStatus === 'finished') {
      updateData.inviterStatus = 'finished';
      updateData.inviteeStatus = 'finished';
    }

    // Wenn beide fertig sind, berechne (beispielhaft) den Gewinner und setze den Status auf "ended"
    if (
      after.inviterStatus === 'finished' &&
      after.inviteeStatus === 'finished' &&
      !after.scores.winner
    ) {
      const score1 = after.scores.user1 || 0;
      const score2 = after.scores.user2 || 0;
      let winner = null;
      if (score1 > score2) winner = after.inviterId;
      else if (score2 > score1) winner = after.inviteeId;
      else winner = "draw";

      updateData['scores.winner'] = winner;
      updateData.inviterStatus = 'ended';
      updateData.inviteeStatus = 'ended';
    }

    if (Object.keys(updateData).length > 0) {
      updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      await change.after.ref.update(updateData);
    }
    return null;
  });