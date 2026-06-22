import 'dart:async';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:dartlab_kernel/kernel/kernel_manager.dart';

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

void main() {
  group('Kernel Protocol Integration Tests', () {
    late StreamController<String> inputStream;
    late StreamController<String> outputStream;
    late KernelManager manager;
    final List<String> receivedLines = [];
    late StreamSubscription<String> outputSubscription;

    setUp(() {
      inputStream = StreamController<String>();
      outputStream = StreamController<String>();
      receivedLines.clear();
      outputSubscription = outputStream.stream.listen((line) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          receivedLines.add(trimmed);
        }
      });
      manager = KernelManager(
        inputStream: inputStream.stream,
        outputSink: StreamControllerSink(outputStream),
      );
      manager.start();
    });

    tearDown(() async {
      await outputSubscription.cancel();
      await manager.shutdown();
      await inputStream.close();
      await outputStream.close();
    });

    test('should execute cell, track variables and capture prints', () async {
      final request1 = jsonEncode({
        'id': '1',
        'type': 'execute',
        'sessionId': 'proto-test-1',
        'payload': {'code': 'var a = 42; print("a is \$a");'},
      });

      inputStream.add(request1);

      // Wait for execution to finish (status idle + response)
      // Usually starts the process which takes ~1.5 - 2s, so we wait 4s to be safe
      await Future.delayed(const Duration(seconds: 4));

      expect(receivedLines, isNotEmpty);

      // Let's parse all received JSON lines
      final parsedList = receivedLines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();

      final busyEvent = parsedList.firstWhere((m) => m['event'] == 'status' && m['payload']['state'] == 'busy');
      expect(busyEvent, isNotNull);

      final stdoutEvent = parsedList.firstWhere((m) => m['event'] == 'stdout');
      expect(stdoutEvent['payload']['content'], equals('a is 42'));

      final idleEvent = parsedList.firstWhere((m) => m['event'] == 'status' && m['payload']['state'] == 'idle');
      expect(idleEvent, isNotNull);

      final response = parsedList.firstWhere((m) => m['id'] == '1');
      expect(response['success'], isTrue);
      expect(response['payload']['success'], isTrue);

      final variables = response['payload']['variables'] as List;
      expect(variables, isNotEmpty);
      expect(variables.first['name'], equals('a'));
      expect(variables.first['value'], equals('42'));
    });

    test('should execute multiple cells sequentially and preserve state', () async {
      final request1 = jsonEncode({
        'id': '1',
        'type': 'execute',
        'sessionId': 'proto-test-2',
        'payload': {'code': 'var x = 100;'},
      });
      final request2 = jsonEncode({
        'id': '2',
        'type': 'execute',
        'sessionId': 'proto-test-2',
        'payload': {'code': 'x += 50;'},
      });

      inputStream.add(request1);
      inputStream.add(request2);

      // Wait for both executions to finish
      await Future.delayed(const Duration(seconds: 5));

      final parsedList = receivedLines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();

      final response1 = parsedList.firstWhere((m) => m['id'] == '1');
      expect(response1['success'], isTrue);

      final response2 = parsedList.firstWhere((m) => m['id'] == '2');
      expect(response2['success'], isTrue);

      final variables2 = response2['payload']['variables'] as List;
      expect(variables2.first['name'], equals('x'));
      expect(variables2.first['value'], equals('150'));
    });

    test('should handle restart and shutdown commands', () async {
      final request1 = jsonEncode({
        'id': '1',
        'type': 'execute',
        'sessionId': 'proto-test-3',
        'payload': {'code': 'var y = 10;'},
      });
      inputStream.add(request1);
      await Future.delayed(const Duration(seconds: 3));

      // Send restart
      final requestRestart = jsonEncode({
        'id': '2',
        'type': 'restart',
        'sessionId': 'proto-test-3',
        'payload': {},
      });
      inputStream.add(requestRestart);
      await Future.delayed(const Duration(seconds: 3));

      // Send shutdown
      final requestShutdown = jsonEncode({
        'id': '3',
        'type': 'shutdown',
        'sessionId': 'proto-test-3',
        'payload': {},
      });
      inputStream.add(requestShutdown);
      await Future.delayed(const Duration(seconds: 1));

      final parsedList = receivedLines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();

      final restartResponse = parsedList.firstWhere((m) => m['id'] == '2');
      expect(restartResponse['success'], isTrue);
      expect(restartResponse['payload']['message'], equals('Session restarted'));

      final shutdownResponse = parsedList.firstWhere((m) => m['id'] == '3');
      expect(shutdownResponse['success'], isTrue);
      expect(shutdownResponse['payload']['message'], equals('Session shutdown'));
    });

    test('should interrupt running execution and maintain declarations', () async {
      // 1. Declare a variable first
      final request1 = jsonEncode({
        'id': '1',
        'type': 'execute',
        'sessionId': 'proto-test-4',
        'payload': {'code': 'var keepMe = 55;'},
      });
      inputStream.add(request1);
      await Future.delayed(const Duration(seconds: 3));

      // 2. Start a long running loop
      final request2 = jsonEncode({
        'id': '2',
        'type': 'execute',
        'sessionId': 'proto-test-4',
        'payload': {'code': 'while (true) {}'},
      });
      inputStream.add(request2);
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Send interrupt command while request2 is running
      final requestInterrupt = jsonEncode({
        'id': '3',
        'type': 'interrupt',
        'sessionId': 'proto-test-4',
        'payload': {},
      });
      inputStream.add(requestInterrupt);
      await Future.delayed(const Duration(seconds: 3));

      // 4. Verify the keepMe variable is still there on a new execution
      final request3 = jsonEncode({
        'id': '4',
        'type': 'execute',
        'sessionId': 'proto-test-4',
        'payload': {'code': 'keepMe += 10;'},
      });
      inputStream.add(request3);
      await Future.delayed(const Duration(seconds: 2));

      final parsedList = receivedLines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();

      // Request 1 should be success
      final response1 = parsedList.firstWhere((m) => m['id'] == '1');
      expect(response1['success'], isTrue);

      // Request 3 (interrupt response) should be success
      final responseInterrupt = parsedList.firstWhere((m) => m['id'] == '3');
      expect(responseInterrupt['success'], isTrue);
      expect(responseInterrupt['payload']['message'], equals('Session interrupted'));

      // Request 2 (the one that got interrupted) should be finished with success = false
      final response2 = parsedList.firstWhere((m) => m['id'] == '2');
      expect(response2['success'], isFalse);

      // Request 4 (subsequent execute) should succeed and have keepMe value 65!
      final response3 = parsedList.firstWhere((m) => m['id'] == '4');
      expect(response3['success'], isTrue);
      final variables = response3['payload']['variables'] as List;
      expect(variables.first['name'], equals('keepMe'));
      expect(variables.first['value'], equals('65'));
    });
  });
}
