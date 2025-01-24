import 'dart:math';

/// Service zur Generierung von Kopfrechen-Aufgaben je nach Schwierigkeitsgrad.
/// Alle Aufgaben sollen immer ein ganzzahliges Ergebnis haben.
/// Division wird mit "/" dargestellt.
/// Äußere Klammern werden entfernt.
/// Anzahl Klammern je nach Level begrenzt:
///   Anfänger: 0
///   Fortgeschritten: 1
///   Experte: 3
///
/// Wir speichern das Ergebnis intern in _lastResult, und geben nur den "cleanen"
/// Ausdruck zurück.
class ArithmeticsService {
  final Random _rnd = Random();

  // Zuletzt erzeugter int-Ergebnis
  int? _lastResult;

  /// Zuletzt erzeugter "Anzeigetext" ohne "#=..."
  String? _lastDisplayedQuestion;

  /// Erzeugt eine Rechenaufgabe als String, passend zum Level.
  /// Beispiel: "2 + 3 - 1", "12 / 3", evtl. einfache Klammern.
  String generateQuestion(String level) {
    // Definiere je nach Level die möglichen Parameter:
    int bracketLimit;
    int operandCountMin;
    int operandCountMax;
    int maxValue;

    switch (level) {
      case 'Anfänger':
        // Keine Klammern
        bracketLimit = 0;
        // 2..3 Operanden
        operandCountMin = 2;
        operandCountMax = 3;
        maxValue = 10; 
        break;
      case 'Fortgeschritten':
        bracketLimit = 1;
        // 2..4 Operanden
        operandCountMin = 2;
        operandCountMax = 4;
        maxValue = 20;
        break;
      case 'Experte':
        bracketLimit = 3;
        // 3..5 Operanden
        operandCountMin = 3;
        operandCountMax = 5;
        maxValue = 30;
        break;
      default:
        // Fallback "Anfänger"
        bracketLimit = 0;
        operandCountMin = 2;
        operandCountMax = 3;
        maxValue = 10;
        break;
    }

    // Schleife, bis wir eine passende Aufgabe finden
    while (true) {
      final operandCount = _rnd.nextInt(operandCountMax - operandCountMin + 1) + operandCountMin;

      final tree = _generateAst(
        operandCount,
        maxValue,
        allowMultiply: true,
        allowDivide: true,
        bracketLimit: bracketLimit,
      );
      if (tree == null) continue;

      final eval = tree.evaluate();
      if (eval == null) continue;

      // Muss ganzzahlig sein
      if ((eval - eval.floorToDouble()).abs() > 1e-9) {
        // Ist keine Ganzzahl
        continue;
      }
      final intResult = eval.toInt();

      if (intResult < 0 || intResult.abs() > 999) {
        // Zu groß/klein => unpraktisch fürs Kopfrechnen
        continue;
      }

      // Baum -> String
      String exprString = tree.toExpressionString();
      // Äußere Klammern entfernen
      exprString = _removeOuterParens(exprString);

      // Hier haben wir einen guten Ausdruck
      _lastResult = intResult;
      _lastDisplayedQuestion = exprString;

      return exprString; 
    }
  }

  /// Prüft, ob `answerString` das korrekte Ergebnis für die zuletzt generierte Aufgabe ist.
  bool checkAnswer(String answerString) {
    if (_lastResult == null) return false;
    final userInt = int.tryParse(answerString.trim());
    if (userInt == null) return false;
    return userInt == _lastResult;
  }

  /// Gibt den zuletzt generierten Ausdruck zurück (falls benötigt).
  String? get lastDisplayedQuestion => _lastDisplayedQuestion;

  // ---------------- Hilfsmethoden ----------------

  /// Entfernt äußerste Klammern, wenn sie das gesamte Expression umschließen.
  String _removeOuterParens(String expr) {
    if (expr.isEmpty) return expr;
    if (expr.startsWith('(') && expr.endsWith(')')) {
      // Prüfe Matching
      int count = 0;
      for (int i = 0; i < expr.length; i++) {
        final ch = expr[i];
        if (ch == '(') count++;
        if (ch == ')') count--;
        if (count == 0 && i < expr.length - 1) {
          // bedeutet, Klammer schließt vorher
          return expr; 
        }
      }
      // War alles ein Paar
      return expr.substring(1, expr.length -1);
    }
    return expr;
  }

  _AstNode? _generateAst(
    int operandCount,
    int maxValue,
    {
      required bool allowMultiply,
      required bool allowDivide,
      required int bracketLimit,
    }
  ) {
    if (operandCount <= 1) {
      final val = _rnd.nextInt(maxValue) + 1;
      return _AstNode.number(val);
    }
    final leftCount = _rnd.nextInt(operandCount -1) + 1;
    final rightCount = operandCount - leftCount;

    final leftAst = _generateAst(leftCount, maxValue, allowMultiply: allowMultiply, allowDivide: allowDivide, bracketLimit: bracketLimit);
    final rightAst = _generateAst(rightCount, maxValue, allowMultiply: allowMultiply, allowDivide: allowDivide, bracketLimit: bracketLimit);
    if (leftAst == null || rightAst == null) return null;

    final possibleOps = <_Operator>[_Operator.add, _Operator.sub];
    if (allowMultiply) possibleOps.add(_Operator.mul);
    if (allowDivide) possibleOps.add(_Operator.div);

    final op = possibleOps[_rnd.nextInt(possibleOps.length)];

    final node = _AstNode.operator(op, leftAst, rightAst);

    // Evtl. Klammern, falls bracketLimit>0
    // Simpler Ansatz: random Chance
    if (bracketLimit > 0 && _rnd.nextBool()) {
      node.hasOwnBracket = true;
      bracketLimit--;
    }
    return node;
  }
}

// ---------------- AST-KNOTEN ----------------

enum _Operator { add, sub, mul, div }

class _AstNode {
  final bool isNumber;
  final int? numberValue;
  final _Operator? op;
  final _AstNode? left;
  final _AstNode? right;

  bool hasOwnBracket = false;

  _AstNode._(this.isNumber, {this.numberValue, this.op, this.left, this.right});

  factory _AstNode.number(int val) {
    return _AstNode._(true, numberValue: val);
  }

  factory _AstNode.operator(_Operator op, _AstNode l, _AstNode r) {
    return _AstNode._(false, op: op, left: l, right: r);
  }

  double? evaluate() {
    if (isNumber) {
      return numberValue?.toDouble();
    }
    if (op == null || left == null || right == null) return null;

    final lv = left!.evaluate();
    final rv = right!.evaluate();
    if (lv == null || rv == null) return null;

    switch(op!) {
      case _Operator.add:
        return lv + rv;
      case _Operator.sub:
        return lv - rv;
      case _Operator.mul:
        return lv * rv;
      case _Operator.div:
        if (rv == 0) return null;
        return lv / rv;
    }
  }

  /// Baut den Ausdruck, z. B. "2 + 3" oder "(2 - 3) / 4"
  /// Division normal via "/".
  /// Keine äußeren Klammern, falls hasOwnBracket == true => wir packen ( ... )
  String toExpressionString() {
    if (isNumber) {
      return numberValue.toString();
    }
    final leftStr = left!.toExpressionString();
    final rightStr = right!.toExpressionString();

    String middleOp;
    switch(op!) {
      case _Operator.add:
        middleOp = " + ";
        break;
      case _Operator.sub:
        middleOp = " - ";
        break;
      case _Operator.mul:
        middleOp = " * ";
        break;
      case _Operator.div:
        middleOp = " / ";
        break;
    }

    final expr = leftStr + middleOp + rightStr;
    if (hasOwnBracket) {
      return "($expr)";
    } else {
      return expr;
    }
  }
}