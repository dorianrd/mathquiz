"use strict";

/**
 * Generates an advanced challenge (level "Fortgeschritten").
 *
 * @return {{question: string, answer: string}}
 */
function generateAdvancedChallenge() {
  // Parameters for "Fortgeschritten" level:
  const bracketLimit = 1;
  const operandCountMin = 2;
  const operandCountMax = 4;
  const maxValue = 20;
  const operators = ["+", "-", "*", "/"];

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const operandCount = Math.floor(
        Math.random() * (operandCountMax - operandCountMin + 1),
    ) + operandCountMin;
    let expression = "";
    for (let i = 0; i < operandCount; i++) {
      const num = Math.floor(Math.random() * maxValue) + 1;
      if (i > 0) {
        const op = operators[
            Math.floor(Math.random() * operators.length)
        ];
        expression += " " + op + " ";
      }
      expression += num.toString();
    }
    // Optionally wrap the expression in parentheses.
    if (bracketLimit > 0 && Math.random() < 0.5) {
      expression = "(" + expression + ")";
    }
    try {
      const result = eval(expression);
      if (
        Number.isInteger(result) &&
        result >= 0 &&
        result < 1000
      ) {
        return {
          question: "Was ist " + expression + "?",
          answer: result.toString(),
        };
      }
    } catch (e) {
      continue;
    }
  }
}

const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {Timestamp} = require("firebase-admin/firestore");
admin.initializeApp();

// This function runs daily at 00:00 (Central European Time)
exports.createDailyChallengeExperte = onSchedule(
    "0 0 * * *",
    async (event) => {
      const db = admin.firestore();
      const now = new Date();
      const year = now.getFullYear().toString().padStart(4, "0");
      const month = (now.getMonth() + 1).toString().padStart(2, "0");
      const day = now.getDate().toString().padStart(2, "0");
      const docId = `${year}-${month}-${day}`;
      const challengeRef = db.collection("daily_challenges").doc(docId);
      const docSnap = await challengeRef.get();
      if (!docSnap.exists) {
        const challenge = generateAdvancedChallenge();
        await challengeRef.set({
          question: challenge.question,
          answer: challenge.answer,
          created_at: Timestamp.now(),
        });
        console.log(
            "Daily Challenge (Experte) for " +
        docId +
            " created: " +
        challenge.question +
            " = " +
        challenge.answer,
        );
      } else {
        console.log("Daily Challenge for " + docId + " already exists.");
      }
      return null;
    },
);
