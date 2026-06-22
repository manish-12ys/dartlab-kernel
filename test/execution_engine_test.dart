import 'package:test/test.dart';
import 'package:dartlab_kernel/session/session_manager.dart';
import 'package:dartlab_kernel/execution/execution_engine.dart';
import 'package:dartlab_kernel/models/execution_result.dart';

void main() {
  group('Execution Engine Integration Tests', () {
    late SessionManager sessionManager;
    late SessionExecutionEngine engine;
    const sessionId = "test-session";

    setUp(() async {
      sessionManager = SessionManager();
      engine = SessionExecutionEngine(sessionManager);
      await sessionManager.createSession(sessionId);
    });

    tearDown(() async {
      await sessionManager.shutdownAll();
    });

    test('should persist variables across cells', () async {
      // Cell 1: Declare a variable
      var result = await engine.execute(sessionId, 'var x = 10;');
      expect(result.success, isTrue);
      expect(result.variables, hasLength(1));
      expect(result.variables.first.name, equals('x'));
      expect(result.variables.first.value, equals('10'));

      // Cell 2: Increment the variable
      result = await engine.execute(sessionId, 'x += 5;');
      expect(result.success, isTrue);
      expect(result.variables, hasLength(1));
      expect(result.variables.first.value, equals('15'));

      // Cell 3: Print the variable
      result = await engine.execute(sessionId, 'print(x);');
      expect(result.success, isTrue);
      expect(result.outputs, hasLength(1));
      expect(result.outputs.first.content, equals('15'));
      expect(result.outputs.first.type, equals(OutputType.stdout));
    });

    test('should persist classes across cells', () async {
      // Cell 1: Define a class
      var result = await engine.execute(sessionId, '''
class Product {
  final String name;
  final double price;
  Product(this.name, this.price);
  String format() => "\$name: \\\$\${price.toStringAsFixed(2)}";
}
''');
      expect(result.success, isTrue);

      // Cell 2: Instantiate it
      result = await engine.execute(sessionId, 'var prod = Product("Laptop", 999.99);');
      expect(result.success, isTrue);

      // Cell 3: Invoke formatted print
      result = await engine.execute(sessionId, 'print(prod.format());');
      expect(result.success, isTrue);
      expect(result.outputs, hasLength(1));
      expect(result.outputs.first.content, equals('Laptop: \$999.99'));
    });

    test('should capture standard error', () async {
      final result = await engine.execute(sessionId, 'stderr.writeln("Warning: Low memory");');
      expect(result.success, isTrue);
      expect(result.outputs, hasLength(1));
      expect(result.outputs.first.type, equals(OutputType.stderr));
      expect(result.outputs.first.content, equals('Warning: Low memory'));
    });

    test('should handle syntax/compile errors gracefully', () async {
      final result = await engine.execute(sessionId, 'var x = ;'); // Invalid syntax
      expect(result.success, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.errors.first.name, equals('CompileError'));
    });

    test('should handle runtime exceptions gracefully', () async {
      final result = await engine.execute(sessionId, 'throw StateError("Invalid operation");');
      expect(result.success, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.errors.first.name, equals('UnhandledException'));
      expect(result.errors.first.message, contains('Invalid operation'));
    });
  });
}
