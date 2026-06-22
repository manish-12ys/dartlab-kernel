import 'package:test/test.dart';
import 'package:dartlab_kernel/execution/source_synthesizer.dart';

void main() {
  group('SourceSynthesizer Tests', () {
    late SourceSynthesizer synthesizer;

    setUp(() {
      synthesizer = SourceSynthesizer();
    });

    test('should parse pure declarations', () {
      final code = '''
import 'dart:math';
class MyClass {
  final int value;
  MyClass(this.value);
}
void helper() {
  print("hello");
}
var myVar = 42;
''';

      final parsed = synthesizer.parseAndIntegrateCell(code);

      expect(parsed.imports, contains("import 'dart:math';"));
      expect(parsed.declarations, hasLength(3)); // MyClass, helper, myVar
      expect(parsed.statements, isEmpty);

      // Verify synthesizer state
      expect(synthesizer.declaredVariableNames, contains('myVar'));
    });

    test('should parse pure statements', () {
      final code = '''
x = x + 10;
print("hello world");
if (x > 50) {
  print("high");
}
''';

      final parsed = synthesizer.parseAndIntegrateCell(code);

      expect(parsed.imports, isEmpty);
      expect(parsed.declarations, isEmpty);
      expect(parsed.statements, isNotEmpty);
      expect(parsed.statements.join('\n'), contains('x = x + 10;'));
      expect(parsed.statements.join('\n'), contains('print("hello world");'));
    });

    test('should parse mixed declarations and statements', () {
      final code = '''
class Counter {
  int count = 0;
  void increment() => count++;
}
var c = Counter();
c.increment();
print(c.count);
''';

      final parsed = synthesizer.parseAndIntegrateCell(code);

      expect(parsed.declarations, hasLength(2)); // Counter class and variable c
      expect(parsed.statements, isNotEmpty);
      expect(parsed.statements.join('\n'), contains('c.increment();'));
      expect(parsed.statements.join('\n'), contains('print(c.count);'));
    });

    test('should overwrite declarations with the same name', () {
      // 1. First definition of class A
      synthesizer.parseAndIntegrateCell('class A { int val = 10; }');
      
      // 2. Redefine class A
      synthesizer.parseAndIntegrateCell('class A { int val = 20; }');

      final content = synthesizer.synthesizeFileContent([]);
      
      // The file should only contain one class A declaration (the latest one)
      expect(content, contains('class A {int val = 20;}'));
      expect(content, isNot(contains('class A {int val = 10;}')));
    });
  });
}
