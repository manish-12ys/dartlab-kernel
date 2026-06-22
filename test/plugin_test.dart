import 'dart:async';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:dartlab_kernel/kernel/kernel.dart';

class MockPlugin extends KernelPlugin {
  bool isInitialized = false;
  String? lastCodeStarted;
  ExecutionResult? lastResultEnded;

  bool throwOnStart = false;

  @override
  String get name => "MockPlugin";

  @override
  FutureOr<void> initialize() {
    isInitialized = true;
  }

  @override
  FutureOr<void> onExecuteStart(String code) {
    if (throwOnStart) {
      throw StateError("Simulated hook error");
    }
    lastCodeStarted = code;
  }

  @override
  FutureOr<void> onExecuteEnd(ExecutionResult result) {
    lastResultEnded = result;
  }
}

void main() {
  group('Plugin Framework Tests', () {
    late StreamController<String> inputStream;
    late StreamController<String> outputStream;
    late KernelManager manager;
    late MockPlugin plugin;
    final List<String> receivedLines = [];
    late StreamSubscription<String> outputSubscription;

    setUp(() async {
      inputStream = StreamController<String>();
      outputStream = StreamController<String>();
      receivedLines.clear();
      outputSubscription = outputStream.stream.listen((line) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          receivedLines.add(trimmed);
        }
      });
      plugin = MockPlugin();
      
      manager = KernelManager(
        inputStream: inputStream.stream,
        outputSink: StreamControllerSink(outputStream),
      );
      
      // Register plugin
      await manager.pluginManager.register(plugin);
      manager.start();
    });

    tearDown(() async {
      await outputSubscription.cancel();
      await manager.shutdown();
      await inputStream.close();
      await outputStream.close();
    });

    test('should register and initialize plugin', () {
      expect(plugin.isInitialized, isTrue);
      expect(manager.pluginManager.plugins, contains(plugin));
    });

    test('should invoke hooks during execution', () async {
      final request = jsonEncode({
        'id': '1',
        'type': 'execute',
        'sessionId': 'plugin-test-1',
        'payload': {'code': 'var testVal = 10;'},
      });

      inputStream.add(request);
      await Future.delayed(const Duration(seconds: 4));

      expect(plugin.lastCodeStarted, equals('var testVal = 10;'));
      expect(plugin.lastResultEnded, isNotNull);
      expect(plugin.lastResultEnded!.success, isTrue);
      expect(plugin.lastResultEnded!.variables.first.name, equals('testVal'));
    });

    test('should not crash pipeline if plugin throws in hooks', () async {
      plugin.throwOnStart = true;
      final request = jsonEncode({
        'id': '1',
        'type': 'execute',
        'sessionId': 'plugin-test-2',
        'payload': {'code': 'var val2 = 20;'},
      });

      inputStream.add(request);
      await Future.delayed(const Duration(seconds: 4));

      // Despite plugin throwing, the execution should still finish successfully
      expect(plugin.lastResultEnded, isNotNull);
      expect(plugin.lastResultEnded!.success, isTrue);
    });
  });
}

class StreamControllerSink implements StringSink {
  final StreamController<String> _controller;
  StreamControllerSink(this._controller);

  @override
  void write(Object? object) {
    _controller.add(object?.toString() ?? '');
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    _controller.add(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    _controller.add(String.fromCharCode(charCode));
  }

  @override
  void writeln([Object? object = ""]) {
    _controller.add('${object?.toString() ?? ""}\n');
  }
}
