// index.js
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {Timestamp} = require("firebase-admin/firestore");
admin.initializeApp();

// Diese Funktion läuft täglich um 00:00 (Mitteleuropäischer Zeit)
exports.createDailyChallengeExperte = onSchedule("0 0 * * *", async (event) => {
  const db = admin.firestore();
  const now = new Date();
  const year = now.getFullYear().toString().padStart(4, "0");
  const month = (now.getMonth() + 1).toString().padStart(2, "0");
  const day = now.getDate().toString().padStart(2, "0");
  const docId = `${year}-${month}-${day}`;
  const challengeRef = db.collection("daily_challenges").doc(docId);
  const docSnap = await challengeRef.get();
  if (!docSnap.exists) {
    // Parameter für den Schwierigkeitsgrad "Experte":
    const operandCount = Math.floor(Math.random() * 3) + 3;
    let expression = "";
    let sum = 0;
    for (let i = 0; i < operandCount; i++) {
      const num = Math.floor(Math.random() * 30) + 1;
      expression += (i === 0 ? "" : " + ") + num;
      sum += num;
    }
    if (Math.random() < 0.5) {
      expression = "(" + expression + ")";
    }
    await challengeRef.set({
      question: `Was ist ${expression}?`,
      answer: sum.toString(),
      created_at: Timestamp.now(),
    });
    console.log(`Daily Challenge (Experte) für ${docId} erstellt.`);
  } else {
    console.log(`Daily Challenge für ${docId} existiert bereits.`);
  }
  return null;
});
