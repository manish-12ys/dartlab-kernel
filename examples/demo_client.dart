import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() async {
  print("=================================================");
  print("      DARTLAB KERNEL - PROTOCOL DEMO CLIENT      ");
  print("=================================================");
  print("Spawning DartLab Kernel process in protocol mode...\n");

  // Spawn the kernel in protocol mode
  final process = await Process.start('dart', [
    'bin/dartlab_kernel.dart',
    '--protocol',
  ]);

  // Listen to the kernel's stdout (where JSON-RPC events/responses are printed)
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    print("[Kernel Out] $line");
  });

  // Listen to the kernel's stderr
  process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    print("[Kernel Stderr] $line");
  });

  final stdinSink = process.stdin;

  // Helper to send a request to the kernel
  Future<void> sendRequest(String id, String type, String sessionId, Map<String, dynamic> payload) async {
    final requestJson = jsonEncode({
      'id': id,
      'type': type,
      'sessionId': sessionId,
      'payload': payload,
    });
    print("\n[Client Send] $requestJson");
    stdinSink.writeln(requestJson);
    await stdinSink.flush();
  }

  const sessionId = "demo-session";

  // Sequence of requests:
  await Future.delayed(const Duration(seconds: 1));

  // 1. Declare a class and variable
  await sendRequest("1", "execute", sessionId, {
    "code": "class User { String name; User(this.name); } var u = User('Alice');"
  });
  await Future.delayed(const Duration(seconds: 3));

  // 2. Perform a stateful print accessing the variable
  await sendRequest("2", "execute", sessionId, {
    "code": "print('Hello ' + u.name);"
  });
  await Future.delayed(const Duration(seconds: 2));

  // 3. Test error handling
  await sendRequest("3", "execute", sessionId, {
    "code": "throw StateError('Invalid state occurred');"
  });
  await Future.delayed(const Duration(seconds: 2));

  // 4. Shutdown session
  await sendRequest("4", "shutdown", sessionId, {});
  await Future.delayed(const Duration(seconds: 1));

  print("\nTerminating kernel process...");
  process.kill();
  await process.exitCode;
  print("Done!");
}
