import 'dart:math' as math;

import 'symbol_context.dart';

/// Result of expression evaluation.
class EvaluationResult {
  final double? value;
  final String? error;

  const EvaluationResult({this.value, this.error});
}

/// Simple safe expression evaluator for basic arithmetic and functions.
class ExpressionEvaluator {
  final double epsilonForDivideByZero;

  /// [epsilonForDivideByZero] treats very small denominators as division-by-zero.
  /// Set to 0 to keep strict (== 0) behavior.
  const ExpressionEvaluator({this.epsilonForDivideByZero = 0});

  /// Evaluate an expression string against a [SymbolContext].
  ///
  /// Supports:
  /// - arithmetic: +, -, *, /, parentheses
  /// - constants: pi
  /// - variables: identifiers resolved from [context]
  /// - functions: sqrt(x), exp(x), ln(x), log(x), sin(x), cos(x), tan(x), pow(x,y)
  EvaluationResult evaluate(String expression, SymbolContext context) {
    try {
      final parser = _ExpressionParser(
        expression,
        context: context,
        epsilonForDivideByZero: epsilonForDivideByZero,
      );
      final result = parser.parse();
      return EvaluationResult(value: result);
    } catch (e) {
      return EvaluationResult(error: e.toString());
    }
  }
}

/// Recursive descent parser that evaluates directly (no string substitution).
class _ExpressionParser {
  final String expr;
  final SymbolContext context;
  final double epsilonForDivideByZero;
  int i = 0;

  _ExpressionParser(
    this.expr, {
    required this.context,
    required this.epsilonForDivideByZero,
  });

  double parse() {
    final v = _parseAddSub();
    _skipWs();
    if (i < expr.length) {
      throw Exception('Unexpected token: "${expr[i]}"');
    }
    return v;
  }

  double _parseAddSub() {
    double result = _parseMulDiv();
    while (i < expr.length) {
      _skipWs();
      if (expr[i] == '+') {
        i++;
        result += _parseMulDiv();
      } else if (expr[i] == '-') {
        i++;
        result -= _parseMulDiv();
      } else {
        break;
      }
    }
    return result;
  }

  double _parseMulDiv() {
    double result = _parseUnary();
    while (i < expr.length) {
      _skipWs();
      if (expr[i] == '*') {
        i++;
        result *= _parseUnary();
      } else if (expr[i] == '/') {
        i++;
        final divisor = _parseUnary();
        if (divisor.abs() <= epsilonForDivideByZero) {
          throw Exception('Division by zero');
        }
        result /= divisor;
      } else {
        break;
      }
    }
    return result;
  }

  double _parseUnary() {
    if (i >= expr.length) throw Exception('Unexpected end of expression');
    _skipWs();
    if (i >= expr.length) throw Exception('Unexpected end of expression');
    if (expr[i] == '-') {
      i++;
      return -_parseUnary();
    }
    if (expr[i] == '+') {
      i++;
      return _parseUnary();
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipWs();
    if (i >= expr.length) throw Exception('Unexpected end of expression');

    // Parentheses
    if (expr[i] == '(') {
      i++;
      final v = _parseAddSub();
      _skipWs();
      if (i >= expr.length || expr[i] != ')') {
        throw Exception('Missing closing parenthesis');
      }
      i++;
      return v;
    }

    // Identifier: variable/function/constant
    if (_isIdentStart(expr[i])) {
      final name = _readIdent();
      _skipWs();

      // Constant
      if (name == 'pi') return math.pi;

      // Function call
      if (i < expr.length && expr[i] == '(') {
        i++; // skip '('
        final args = <double>[];
        _skipWs();
        if (i < expr.length && expr[i] == ')') {
          i++; // empty args
        } else {
          while (true) {
            final arg = _parseAddSub();
            args.add(arg);
            _skipWs();
            if (i >= expr.length) throw Exception('Missing closing parenthesis');
            if (expr[i] == ',') {
              i++;
              continue;
            }
            if (expr[i] == ')') {
              i++;
              break;
            }
            throw Exception('Unexpected token in function args: "${expr[i]}"');
          }
        }
        return _evalFunction(name, args);
      }

      // Variable
      final v = context.getValue(name);
      if (v == null) {
        throw Exception('Variable not found: $name');
      }
      return v;
    }

    // Number literal
    final num = _readNumber();
    return num;
  }

  double _evalFunction(String name, List<double> args) {
    switch (name) {
      case 'sqrt':
        if (args.length != 1) throw Exception('sqrt() expects 1 argument');
        if (args[0] < 0) throw Exception('Cannot take square root of negative number');
        return math.sqrt(args[0]);
      case 'exp':
        if (args.length != 1) throw Exception('exp() expects 1 argument');
        final v = math.exp(args[0]);
        if (!v.isFinite) {
          throw Exception('exp overflow');
        }
        return v;
      case 'ln':
        if (args.length != 1) throw Exception('ln() expects 1 argument');
        if (args[0] <= 0) throw Exception('ln() domain error');
        return math.log(args[0]);
      case 'log':
        if (args.length != 1) throw Exception('log() expects 1 argument');
        if (args[0] <= 0) throw Exception('log() domain error');
        return math.log(args[0]) / math.ln10;
      case 'sin':
        if (args.length != 1) throw Exception('sin() expects 1 argument');
        return math.sin(args[0]);
      case 'cos':
        if (args.length != 1) throw Exception('cos() expects 1 argument');
        return math.cos(args[0]);
      case 'tan':
        if (args.length != 1) throw Exception('tan() expects 1 argument');
        return math.tan(args[0]);
      case 'pow':
        if (args.length != 2) throw Exception('pow() expects 2 arguments');
        final v = math.pow(args[0], args[1]).toDouble();
        if (!v.isFinite) {
          throw Exception('pow overflow');
        }
        return v;
      default:
        throw Exception('Unknown function: $name');
    }
  }

  bool _isIdentStart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || c == '_';
  }

  bool _isIdentPart(String c) {
    final code = c.codeUnitAt(0);
    return _isIdentStart(c) || (code >= 48 && code <= 57);
  }

  String _readIdent() {
    final start = i;
    while (i < expr.length && _isIdentPart(expr[i])) {
      i++;
    }
    return expr.substring(start, i);
  }

  double _readNumber() {
    _skipWs();
    final start = i;
    bool sawDigit = false;

    // integer/decimal part
    while (i < expr.length) {
      final ch = expr[i];
      final code = ch.codeUnitAt(0);
      final isDigit = code >= 48 && code <= 57;
      if (isDigit) {
        sawDigit = true;
        i++;
        continue;
      }
      if (ch == '.') {
        i++;
        continue;
      }
      break;
    }

    // exponent part
    if (i < expr.length && (expr[i] == 'e' || expr[i] == 'E')) {
      final ePos = i;
      i++;
      if (i < expr.length && (expr[i] == '+' || expr[i] == '-')) {
        i++;
      }
      bool expDigits = false;
      while (i < expr.length) {
        final code = expr[i].codeUnitAt(0);
        if (code >= 48 && code <= 57) {
          expDigits = true;
          i++;
        } else {
          break;
        }
      }
      // If "e" wasn't followed by digits, rewind to before exponent.
      if (!expDigits) {
        i = ePos;
      }
    }

    final raw = expr.substring(start, i);
    if (!sawDigit && raw != '.') {
      throw Exception('Invalid number: "$raw"');
    }
    return double.parse(raw);
  }

  void _skipWs() {
    while (i < expr.length && expr[i].trim().isEmpty) {
      i++;
    }
  }
}



