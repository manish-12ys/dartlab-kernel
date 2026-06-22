import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

class ParsedCell {
  final List<String> imports;
  final List<String> declarations;
  final List<String> statements;

  ParsedCell({
    required this.imports,
    required this.declarations,
    required this.statements,
  });
}

class SourceSynthesizer {
  final Set<String> _imports = {};
  
  // Maps to store top-level declarations by name, so new definitions overwrite old ones.
  final Map<String, String> _classes = {};
  final Map<String, String> _functions = {};
  final Map<String, String> _enums = {};
  final Map<String, String> _mixins = {};
  final Map<String, String> _extensions = {};
  final Map<String, String> _typedefs = {};
  final Map<String, String> _variables = {};

  Set<String> get declaredVariableNames => _variables.keys.toSet();

  SourceSynthesizer();

  /// Parses a cell and integrates its declarations and imports into the synthesizer's state.
  /// Returns the statements/expressions that should be run for this cell.
  ParsedCell parseAndIntegrateCell(String code) {
    final result = parseString(content: code, throwIfDiagnostics: false);
    final unit = result.unit;

    final cellImports = <String>[];
    final cellDeclarations = <String>[];
    final validSpans = <(int, int)>[];

    // 1. Directives (e.g. imports)
    for (final directive in unit.directives) {
      if (directive is ImportDirective) {
        final importStr = directive.toSource();
        cellImports.add(importStr);
        _imports.add(importStr);
        validSpans.add((directive.offset, directive.end));
      }
    }

    // 2. Declarations
    for (final decl in unit.declarations) {
      bool isValid = false;
      String? name;
      Map<String, String>? targetMap;

      // Filter out dummy error-recovery declarations
      final hasSyntaxErrors = result.errors.any(
        (err) => err.offset >= decl.offset && err.offset < decl.end,
      );

      if (!hasSyntaxErrors) {
        if (decl is ClassDeclaration) {
          isValid = true;
          name = decl.namePart.typeName.lexeme;
          targetMap = _classes;
        } else if (decl is EnumDeclaration) {
          isValid = true;
          name = decl.namePart.typeName.lexeme;
          targetMap = _enums;
        } else if (decl is MixinDeclaration) {
          isValid = true;
          name = decl.name.lexeme;
          targetMap = _mixins;
        } else if (decl is ExtensionDeclaration) {
          isValid = true;
          name = decl.name?.lexeme ?? 'anonymous_${_extensions.length}';
          targetMap = _extensions;
        } else if (decl is TypeAlias) {
          isValid = true;
          name = decl.name.lexeme;
          targetMap = _typedefs;
        } else if (decl is TopLevelVariableDeclaration) {
          final hasKeyword = decl.variables.keyword != null;
          final hasType = decl.variables.type != null;
          if (hasKeyword || hasType) {
            isValid = true;
            // Store each variable in the declaration
            for (final variable in decl.variables.variables) {
              final varName = variable.name.lexeme;
              _variables[varName] = decl.toSource();
            }
          }
        } else if (decl is FunctionDeclaration) {
          if (decl.functionExpression.body is! EmptyFunctionBody) {
            isValid = true;
            name = decl.name.lexeme;
            targetMap = _functions;
          }
        }
      }

      if (isValid) {
        final source = decl.toSource();
        cellDeclarations.add(source);
        validSpans.add((decl.offset, decl.end));
        if (targetMap != null && name != null) {
          targetMap[name] = source;
        }
      }
    }

    // Sort spans by start offset to extract remaining statements
    validSpans.sort((a, b) => a.$1.compareTo(b.$1));

    final cellStatements = <String>[];
    int currentPos = 0;
    for (final span in validSpans) {
      final start = span.$1;
      final end = span.$2;
      if (start > currentPos) {
        final chunk = code.substring(currentPos, start).trim();
        if (chunk.isNotEmpty) {
          cellStatements.add(chunk);
        }
      }
      currentPos = end;
    }
    if (currentPos < code.length) {
      final chunk = code.substring(currentPos).trim();
      if (chunk.isNotEmpty) {
        cellStatements.add(chunk);
      }
    }

    return ParsedCell(
      imports: cellImports,
      declarations: cellDeclarations,
      statements: cellStatements,
    );
  }

  /// Synthesizes the full Dart file content, including all accumulated imports and declarations,
  /// plus the current cell's execution block.
  String synthesizeFileContent(List<String> currentCellStatements) {
    final sb = StringBuffer();

    // 1. Core imports required for the runner lifecycle
    sb.writeln("import 'dart:async';");
    sb.writeln("import 'dart:io';");

    // 2. Accumulated imports from cells
    for (final import in _imports) {
      sb.writeln(import);
    }
    sb.writeln();

    // 3. Accumulated declarations
    for (final decl in _variables.values) {
      sb.writeln(decl);
    }
    for (final decl in _classes.values) {
      sb.writeln(decl);
    }
    for (final decl in _functions.values) {
      sb.writeln(decl);
    }
    for (final decl in _enums.values) {
      sb.writeln(decl);
    }
    for (final decl in _mixins.values) {
      sb.writeln(decl);
    }
    for (final decl in _extensions.values) {
      sb.writeln(decl);
    }
    for (final decl in _typedefs.values) {
      sb.writeln(decl);
    }
    sb.writeln();

    // 4. Global helpers for async execution
    sb.writeln('dynamic _lastResult;');
    sb.writeln('dynamic _lastError;');
    sb.writeln('dynamic _lastStackTrace;');
    sb.writeln('bool _cellCompleted = false;');
    sb.writeln();
    sb.writeln('''
dynamic _executeCellWrapper() {
  _lastResult = null;
  _lastError = null;
  _lastStackTrace = null;
  _cellCompleted = false;
  try {
    final res = _executeCell();
    if (res is Future) {
      res.then((val) {
        _lastResult = val;
        _cellCompleted = true;
      }).catchError((err, stack) {
        _lastError = err;
        _lastStackTrace = stack;
        _cellCompleted = true;
      });
      return res;
    } else {
      _lastResult = res;
      _cellCompleted = true;
      return res;
    }
  } catch (e, s) {
    _lastError = e;
    _lastStackTrace = s;
    _cellCompleted = true;
    rethrow;
  }
}
''');
    sb.writeln();

    // 5. Main function to keep the process alive
    sb.writeln('''
void main() async {
  print("RUNNER_READY");
  final completer = Completer<void>();
  stdin.listen(
    (data) {},
    onDone: () => completer.complete(),
  );
  await completer.future;
}
''');
    sb.writeln();

    // 6. Current Cell execution wrapper
    sb.writeln('dynamic _executeCell() async {');
    for (final stmt in currentCellStatements) {
      sb.writeln('  $stmt');
    }
    sb.writeln('}');

    return sb.toString();
  }
}
