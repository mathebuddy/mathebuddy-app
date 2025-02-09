/// MatheBuddy - a gamified app for higher math
/// https://mathebuddy.github.io/
/// (c) 2022-2024 by TH Koeln
/// Author: Andreas Schwenk contact@compiler-construction.com
/// Funded by: FREIRAUM 2022, Stiftung Innovation in der Hochschullehre
/// License: GPL-3.0-or-later

library math_runtime;

import 'dart:math' as math;

import 'help.dart';
import 'term.dart';

/// The term parser, which implements robust parsing of math string provided
/// by students and SMPL Language.
///
/// Note: Code comments "***" indicate semantical useless lines that just
///       prevent linter warnings.
///
/// <GRAMMAR>
///   term =
///     lor;
///   lor =
///     land [ "||" land ];
///   land =
///     equal [ "&&" equal ];
///   equal =
///     relational [ ("=="|"!=") relational ];
///   relational =
///     add [ ("<"|"<="|">"|">=") add ];
///   add =
///     mul { ("+"|"-") mul };
///   mul =
///     pow { ("*"|"/"|<fill"*">) pow };
///   pow =
///     unary [ "^" unary ];
///   unary =
///       "-" mul
///     | "!" infix [ postfix ]
///     | infix [ postfix ];
///   infix =
///       "true"
///     | "false"
///     | "inf"
///     | IMAG
///     | INT
///     | REAL
///     | IRRATIONAL
///     | fct1 unary
///     | (fct0|fct1|fct2|fct3|fct4)
///         [ "<" unary {","unary} ">" ]       # dimensions
///         "(" term {","term} ")";            # arguments
///     | ID
///     | "(" term ")"
///     | "|" term "|"
///     | matrixOrVector
///     | set;
///   postfix =
///       "[" term "]"              # vector index
///     | "[" term "," term "]";    # matrix index
///   vector =
///     "[" [ term { "," term } ] "]";
///   matrixOrVector =
///       vector
///     | "[" [ vector { "," vector } ] "]";
///   set =
///     "{" [ term { "," term } ] "}";
///   fct0 =
///     | "eye"
///     | "zeros"
///     | "ones";
///   fct1 =
///       "abs"
///     | "arg"
///     | "ceil"
///     | "cols"
///     | "conj"
///     | "cos"
///     | "det"
///     | "exp"
///     | "fac"
///     | "floor"
///     | "imag"
///     | "is_invertible"
///     | "is_symmetric"
///     | "is_zero"
///     | "len"
///     | "ln"
///     | "max"
///     | "min"
///     | "norm"
///     | "opt"
///     | "real"
///     | "round"
///     | "rows"
///     | "shuffle"
///     | "sin"
///     | "sqrt"
///     | "tan"
///     | "term"
///     | "transpose"
///     | "triu";
///   fct2 =
///       "binomial"
///     | "complex"
///     | "col"
///     | "cross"
///     | "diff"
///     | "dot"
///     | "rand"
///     | "randZ"
///     | "row";
///   fct4 =
///       "int";
///   IRRATIONAL =
///       "pi"
///     | "e";
///   IMAG =
///     REAL "i";
///   REAL =
///     INT "." { NUM0 };
///   INT =
///       "0"
///     | NUM1 { NUM0 };
///   ID =
///     ALPHA { (ALPHA | NUM0) };
///   NUM0 =
///     "0" | "1" | ... | "9";
///   NUM1 =
///     "1" | "2" | ... | "9";
/// </GRAMMAR>

const fct0 = [
  'eye', //
  'ones', //
  'zeros', //
];
const fct1 = [
  'abs', //
  'arg', //
  'ceil', //
  'cols', //
  'conj', //
  'cos', //
  'det', //
  'exp', //
  'fac', //
  'floor', //
  'imag', //
  'len', //
  'ln', //
  'max', //
  'min', //
  'norm', //
  'opt', //
  'rand', //
  'real', //
  'round', //
  'rows', //
  'shuffle', //
  'sin', //
  'sqrt', //
  'tan', //
  'term', //
  'transpose', //
  'triu', //
  "is_invertible", //
  "is_symmetric", //
  "is_zero", //
];
const fct2 = [
  'binomial', //
  'col', //
  'complex', //
  'cross', //
  'diff', //
  'dot', //
  'rand', //
  'randZ', //
  'row', //
];
const fct3 = [];
const fct4 = [
  "int" //
];

class Parser {
  List<String> _tokens = [];
  int _tokenIdx = 0;
  String _token = '';

  Parser() {
    //
  }

  List<String> getTokens() {
    return _tokens;
  }

  Term parse(String src, {splitIdentifiers = true}) {
    _tokens = [];
    _tokenIdx = 0;
    // scanning (lexing)
    var tk = ''; // token
    for (var i = 0; i < src.length; i++) {
      var ch = src[i];
      var ch2 = i + 1 < src.length ? src[i + 1] : '';
      if (' \t\n'.contains(ch)) {
        if (tk.isNotEmpty) {
          _tokens.add(tk);
          tk = '';
        }
      } else if ('+-*/()^{},|[]<>=!&@'.contains(ch)) {
        if (tk.isNotEmpty) {
          _tokens.add(tk);
          tk = '';
        }
        _tokens.add(ch);
        if ((ch == '&' && ch2 == '&') ||
            (ch == '|' && ch2 == '|') ||
            (ch == '>' && ch2 == '=') ||
            (ch == '<' && ch2 == '=') ||
            (ch == '=' && ch2 == '=') ||
            (ch == '!' && ch2 == '=') ||
            (ch == '@' && ch2 == '@')) {
          _tokens[_tokens.length - 1] += ch2;
          i++;
        }
      } else {
        tk += ch;
      }
    }
    if (tk.isNotEmpty) {
      _tokens.add(tk);
    }
    _tokens.add('§');
    // post-process tokens
    List<String> procTokens = [];
    for (var k = 0; k < _tokens.length; k++) {
      var token = _tokens[k];
      if (splitIdentifiers &&
          token != "true" &&
          token != "false" &&
          _isIdentifier(token) &&
          _isFct0(token) == false &&
          _isFct1(token) == false &&
          _isFct2(token) == false &&
          _isFct3(token) == false &&
          _isFct4(token) == false &&
          _isBuiltIn(token) == false) {
        // split variables (e.g. "xy" -> "x y")
        for (var i = 0; i < token.length; i++) {
          var char = token[i];
          procTokens.add(char);
        }
      } else if (token.length >= 2 &&
          _isNum0(token[0]) &&
          _isAlpha(token[token.length - 1])) {
        // split factors (e.g. "3x" -> "3 x")
        var value = '';
        var id = '';
        for (var i = 0; i < token.length; i++) {
          var ch = token[i];
          if (id.isEmpty && _isNum0(ch)) {
            value += ch;
          } else {
            id += ch;
          }
        }
        procTokens.add(value);
        procTokens.add(id); // TODO: split variables!!!!!
      } else {
        // no post-processing
        procTokens.add(token);
      }
    }
    _tokens = procTokens;
    // resolve randomized token selection, e.g. "1{+|-}2" -> "1+2" or "1-2"
    procTokens = [];
    for (var i = 0; i < _tokens.length; i++) {
      if (_tokens[i] == '{' &&
          i + 1 < _tokens.length &&
          _tokens[i + 1] != '}') {
        List<String> op = [];
        var valid = true;
        int k;
        for (k = i + 1; k < _tokens.length; k++) {
          if (_tokens[k] == '}') break;
          if ('+-*/'.contains(_tokens[k]) == false) {
            valid = false;
            break;
          }
          op.add(_tokens[k]);
          k++;
          if (k >= _tokens.length) {
            valid = false;
            break;
          }
          if (_tokens[k] != '|' && _tokens[k] != '}') {
            valid = false;
            break;
          }
          if (_tokens[k] == '}') break;
        }
        if (valid) {
          i = k;
          procTokens.add(
            op[(math.Random().nextDouble() * op.length).floor()],
          );
        } else {
          procTokens.add('{');
        }
      } else {
        procTokens.add(_tokens[i]);
      }
    }
    _tokens = procTokens;
    // parsing
    _next();
    var term = _parseTerm();
    if (_token != '§') throw Exception('unexpected:end');
    return term;
  }

  Term _parseTerm() {
    return _parseLor();
  }

  Term _parseLor() {
    var res = _parseLand();
    if (_token == '||') {
      var op = _token;
      _next();
      res = Term.createOp(op, [res, _parseLand()], []);
    }
    return res;
  }

  Term _parseLand() {
    var res = _parseEqual();
    if (_token == '&&') {
      var op = _token;
      _next();
      res = Term.createOp(op, [res, _parseEqual()], []);
    }
    return res;
  }

  Term _parseEqual() {
    var res = _parseRelational();
    if (['==', '!='].contains(_token)) {
      var op = _token;
      _next();
      res = Term.createOp(op, [res, _parseRelational()], []);
    }
    return res;
  }

  Term _parseRelational() {
    var res = _parseAdd();
    if (['<', '<=', '>', '>='].contains(_token)) {
      var op = _token;
      _next();
      res = Term.createOp(op, [res, _parseAdd()], []);
    }
    return res;
  }

  Term _parseAdd() {
    List<Term> operands = [];
    List<String> operators = [];
    operands.add(_parseMul());
    while (_token == '+' || _token == '-') {
      operators.add(_token);
      _next();
      operands.add(_parseMul());
    }
    if (operators.length == 1 && operators[0] == '-') {
      // form: "o[0] - o[1]"
      return Term.createOp('-', operands, []);
    } else if (operators.isNotEmpty) {
      // form: "o[0] op[0] b[1] op[1] ..."
      // -> "o[0] + o[1] + ..."  with o[i+1] := -o[i+1] for op[i]=='-'
      for (var i = 0; i < operators.length; i++) {
        if (operators[i] == '-') {
          operands[i + 1] = Term.createOp('.-', [operands[i + 1]], []);
        }
      }
      return Term.createOp('+', operands, []);
    } else {
      // form: "o[0]"
      return operands[0];
    }
  }

  Term _parseMul() {
    List<Term> operands = [];
    List<String> operators = [];
    operands.add(_parsePow());
    while (_token == '*' ||
        _token == '/' ||
        (_token != '§' && (_isIdentifier(_token) || _token == '('))) {
      var op = _token == '/' ? '/' : '*';
      operators.add(op);
      if (_token == '*' || _token == '/') _next();
      operands.add(_parsePow());
    }
    if (operands.length == 1) {
      return operands[0];
    } else if (operators.length == 1 && operators[0] == '/') {
      return Term.createOp('/', operands, []);
    } else if (operators.contains('/')) {
      Term o = operands[0];
      for (var i = 0; i < operators.length; i++) {
        o = Term.createOp(operators[i], [o, operands[i + 1]], []);
      }
      return o;
    } else {
      return Term.createOp('*', operands, []);
    }
  }

  Term _parsePow() {
    List<Term> operands = [];
    operands.add(_parseUnary());
    if (_token == '^') {
      _next();
      operands.add(_parseUnary());
      return Term.createOp('^', operands, []);
    } else {
      return operands[0];
    }
  }

  Term _parseUnary() {
    if (_token == '-') {
      _next();
      var mul = _parseMul();
      return Term.createOp('.-', [mul], []);
    } else if (_token == '!') {
      // TODO: postfix not parsed here!
      _next();
      var operand = _parseInfix();
      return Term.createOp('!', [operand], []);
    } else {
      var t = _parseInfix();
      if (_isPostfix()) {
        t = _parsePostfix(t);
      }
      return t;
    }
  }

  Term _parseInfix() {
    if (_token == 'true') {
      _next();
      return Term.createConstBoolean(true);
    } else if (_token == 'false') {
      _next();
      return Term.createConstBoolean(false);
    } else if (_token == 'inf') {
      _next();
      return Term.createConstInfinity();
    } else if (_isImag(_token)) {
      var tk = _token;
      _next();
      if (tk == 'i') tk = '1i';
      var im = num.parse(tk.substring(0, tk.length - 1));
      return Term.createConstComplex(0, im);
    } else if (_isInteger(_token)) {
      var value = int.parse(_token);
      _next();
      return Term.createConstInt(value);
    } else if (_isReal(_token)) {
      var value = num.parse(_token);
      _next();
      return Term.createConstReal(value);
    } else if (_isBuiltIn(_token)) {
      var id = _token;
      _next();
      return Term.createConstIrrational(id);
    } else if (_isFct0(_token) ||
        _isFct1(_token) ||
        _isFct2(_token) ||
        _isFct3(_token) ||
        _isFct4(_token)) {
      var fctId = _token;
      var isNullary = _isFct0(_token);
      var isUnary = _isFct1(_token);
      var isBinary = _isFct2(_token);
      var isTernary = _isFct3(_token);
      var isQuaternary = _isFct4(_token);
      List<Term> params = [];
      List<Term> dims = [];
      _next();
      if (_token == '<') {
        _next();
        dims.add(_parseUnary());
        _token += ''; // ***
        while (_token == ',') {
          _next();
          dims.add(_parseUnary());
        }
        if (_token == '>') {
          _next();
        } else {
          throw Exception('expected ">"');
        }
      }
      if (_token == '(') {
        _token += ''; // ***
        _next();
        if (isNullary == false) {
          params.add(_parseTerm());
          while (_token == ',') {
            _next();
            params.add(_parseTerm());
          }
        }
        if (_token == ')') {
          _next();
        } else {
          throw Exception('expected ")"');
        }
        if (isNullary && params.isEmpty ||
            isUnary && params.length == 1 ||
            isBinary && params.length == 2 ||
            isTernary && params.length == 3 ||
            isQuaternary && params.length == 4) {
          // OK
        } else {
          throw Exception('function $fctId got wrong number of arguments');
        }
        return Term.createOp(fctId, params, dims);
      } else if (isUnary && dims.isEmpty) {
        params.add(_parseUnary());
        return Term.createOp(fctId, params, dims);
      } else {
        throw Exception('expected "(" or a unary function');
      }
    } else if (_isIdentifier(_token)) {
      var id = _token;
      _next();
      return Term.createVar(id);
    } else if (_token == '(') {
      _token += ''; // ***
      _next();
      var t = _parseTerm();
      if (_token == ')') {
        _next();
      } else {
        throw Exception('expected: ")"');
      }
      return t;
    } else if (_token == '|') {
      _token += ''; // ***
      _next();
      var t = _parseTerm();
      if (_token == '|') {
        _next();
      } else {
        throw Exception('expected:"|"');
      }
      return Term.createOp('abs', [t], []);
    } else if (_token == '[') {
      return _parseMatrixOrVector();
    } else if (_token == '{') {
      return _parseSet();
    } else {
      throw Exception('unexpected:$_token');
    }
  }

  bool _isPostfix() {
    return _token == '[';
  }

  Term _parsePostfix(Term infix) {
    if (_token == '[') {
      _next();
    } else {
      throw Exception('expected "["');
    }
    var index1 = _parseTerm();
    var res = Term.createOp('index1', [infix, index1], []);
    if (_token == ',') {
      _next();
      var index2 = _parseTerm();
      res = Term.createOp('index2', [infix, index1, index2], []);
    }
    if (_token == ']') {
      _next();
    } else {
      throw Exception('expected "]"');
    }
    return res;
  }

  Term _parseVector([bool parseLeftBracket = true]) {
    if (parseLeftBracket) {
      if (_token == '[') {
        _next();
      } else {
        throw Exception('expected "["');
      }
    }
    _token += ''; // ***
    List<Term> elements = [];
    if (_token != ']') {
      elements.add(_parseTerm());
      while (_token == ',') {
        _next();
        elements.add(_parseTerm());
      }
    }
    if (_token == ']') {
      _next();
    } else {
      throw Exception('expected "]"');
    }
    return Term.createOp('vec', elements, []);
  }

  Term _parseMatrixOrVector() {
    if (_token == '[') {
      _next();
    } else {
      throw Exception('expected "["');
    }
    if (_token != '[') {
      return _parseVector(false);
    }
    _token += ''; // ***
    List<Term> elements = [];
    if (_token != ']') {
      elements.add(_parseVector());
      while (_token == ',') {
        _next();
        elements.add(_parseVector());
      }
    }
    if (_token == ']') {
      _next();
    } else {
      throw Exception('expected "]"');
    }
    return Term.createOp('matrix', elements, []);
  }

  Term _parseSet() {
    // TODO: allow empty sets
    if (_token == '{') {
      _next();
    } else {
      throw Exception('expected "{"');
    }
    _token += ''; // ***
    List<Term> elements = [];
    if (_token != '}') {
      elements.add(_parseTerm());
      while (_token == ',') {
        _next();
        elements.add(_parseTerm());
      }
    }
    if (_token == '}') {
      _next();
    } else {
      throw Exception('expected "}"');
    }
    return Term.createOp('set', elements, []);
  }

  bool _isFct0(String tk) {
    return fct0.contains(tk);
  }

  bool _isFct1(String tk) {
    return fct1.contains(tk);
  }

  bool _isFct2(String tk) {
    return fct2.contains(tk);
  }

  bool _isFct3(String tk) {
    return fct3.contains(tk);
  }

  bool _isFct4(String tk) {
    return fct4.contains(tk);
  }

  bool _isBuiltIn(String tk) {
    var builtin = ['pi', 'e', 'inf'];
    return builtin.contains(tk);
  }

  bool _isImag(String tk) {
    if (tk.endsWith('i') == false) return false;
    var x = tk.substring(0, tk.length - 1);
    if (_isReal(x) == false && _isInteger(x) == false) return false;
    return true;
  }

  bool _isReal(String tk) {
    var tokens = tk.split('.');
    if (tokens.length != 2) return false;
    if (_isInteger(tokens[0]) == false) return false;
    for (var i = 0; i < tokens[1].length; i++) {
      var ch = tokens[1][i];
      if (_isNum0(ch) == false) return false;
    }
    return true;
  }

  bool _isInteger(String tk) {
    if (tk == '0') return true;
    for (var i = 0; i < tk.length; i++) {
      var ch = tk[i];
      if (i == 0 && _isNum1(ch) == false) {
        return false;
      } else if (i > 0 && _isNum0(ch) == false) {
        return false;
      }
    }
    return true;
  }

  bool _isNum0(String tk) {
    return tk.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        tk.codeUnitAt(0) <= '9'.codeUnitAt(0);
  }

  bool _isNum1(String tk) {
    return tk.codeUnitAt(0) >= '1'.codeUnitAt(0) &&
        tk.codeUnitAt(0) <= '9'.codeUnitAt(0);
  }

  bool _isAlpha(String tk) {
    return isAlpha(tk);
  }

  bool _isIdentifier(String tk) {
    var n = tk.length;
    for (var i = 0; i < n; i++) {
      var ch = tk[i];
      if (i == 0 && !_isAlpha(ch)) {
        return false;
      } else if (!_isAlpha(ch) && !_isNum0(ch)) {
        return false;
      }
    }
    return true;
  }

  void _next() {
    if (_tokenIdx >= _tokens.length) {
      _token = '§';
      return;
    }
    _token = _tokens[_tokenIdx++];
  }
}
