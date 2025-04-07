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
    int bracketLimit;
    int operandCountMin;
    int operandCountMax;
    int maxValue;

    switch (level) {
      case 'Anfänger':
        bracketLimit = 0;
        operandCountMin = 2;
        operandCountMax = 3;
        maxValue = 10; 
        break;
      case 'Fortgeschritten':
        bracketLimit = 1;
        operandCountMin = 2;
        operandCountMax = 4;
        maxValue = 20;
        break;
      case 'Experte':
        bracketLimit = 3;
        operandCountMin = 3;
        operandCountMax = 5;
        maxValue = 30;
        break;
      default:
        bracketLimit = 0;
        operandCountMin = 2;
        operandCountMax = 3;
        maxValue = 10;
        break;
    }

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
      // Ensure the result is an integer.
      if ((eval - eval.floorToDouble()).abs() > 1e-9) continue;
      final intResult = eval.toInt();
      if (intResult < 0 || intResult.abs() > 999) continue;
      String exprString = tree.toExpressionString();
      exprString = _removeOuterParens(exprString);
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

  String? get lastDisplayedQuestion => _lastDisplayedQuestion;
  int get getLastResult => _lastResult!;

  _AstNode? _generateAst(
    int operandCount,
    int maxValue, {
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
    if (bracketLimit > 0 && _rnd.nextBool()) {
      node.hasOwnBracket = true;
      bracketLimit--;
    }
    return node;
  }

  String _removeOuterParens(String expr) {
    if (expr.isEmpty) return expr;
    if (expr.startsWith('(') && expr.endsWith(')')) {
      int count = 0;
      for (int i = 0; i < expr.length; i++) {
        final ch = expr[i];
        if (ch == '(') count++;
        if (ch == ')') count--;
        if (count == 0 && i < expr.length - 1) {
          return expr;
        }
      }
      return expr.substring(1, expr.length -1);
    }
    return expr;
  }
}

/// ---------------- AST-KNOTEN ----------------

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
        // Ensure both operands are whole numbers
        final intLv = lv.toInt();
        final intRv = rv.toInt();
        if (intLv.toDouble() != lv || intRv.toDouble() != rv) return null;
        if (intLv % intRv != 0) return null;
        return (intLv ~/ intRv).toDouble();
    }
  }

  // Helper function to determine operator precedence.
  int _precedence(_Operator op) {
    switch(op) {
      case _Operator.add:
      case _Operator.sub:
        return 1;
      case _Operator.mul:
      case _Operator.div:
        return 2;
    }
  }

  /// Returns the expression as a String with minimal parentheses,
  /// respecting operator precedence (multiplication and division are done before addition and subtraction).
  String toExpressionString() {
    if (isNumber) {
      return numberValue.toString();
    }
    
    // Get left and right expression strings
    String leftStr = left!.toExpressionString();
    String rightStr = right!.toExpressionString();
    
    // If left child is an operator, add parentheses if its precedence is lower than the current node's precedence.
    if (!left!.isNumber && left!.op != null) {
      if (_precedence(left!.op!) < _precedence(op!)) {
        leftStr = "($leftStr)";
      }
    }
    
    // For the right child, if its operator precedence is lower or equal (for non-associative operators like '-' or '/') add parentheses.
    if (!right!.isNumber && right!.op != null) {
      if (_precedence(right!.op!) < _precedence(op!) ||
          (_precedence(right!.op!) == _precedence(op!) &&
              (op == _Operator.sub || op == _Operator.div))) {
        rightStr = "($rightStr)";
      }
    }
    
    String opSymbol;
    switch(op!) {
      case _Operator.add:
        opSymbol = " + ";
        break;
      case _Operator.sub:
        opSymbol = " - ";
        break; 
      case _Operator.mul:
        opSymbol = " * ";
        break;
      case _Operator.div:
        opSymbol = " / ";
        break;
    }
    
    final expr = leftStr + opSymbol + rightStr;
    if (hasOwnBracket) {
      return "($expr)";
    } else {
      return expr;
    }
  }
}