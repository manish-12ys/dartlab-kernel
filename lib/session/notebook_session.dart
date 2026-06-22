import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart';
import '../models/execution_result.dart';
import '../models/variable_info.dart';
import '../execution/source_synthesizer.dart';
import '../execution/execution_queue.dart';

class NotebookSession {
  final String id;
  final String sessionDir;
  late final String sessionFilePath;

  Process? _process;
  vms.VmService? _vmService;
  String? _isolateId;
  String? _libraryId;

  final SourceSynthesizer _synthesizer = SourceSynthesizer();
  final ExecutionQueue _queue = ExecutionQueue();
  final List<OutputItem> _capturedOutputs = [];
  bool _isExecuting = false;

  final void Function(OutputType type, String line)? onOutputEvent;
  final void Function(String state)? onStatusEvent;

  NotebookSession({
    required this.id,
    this.sessionDir = '.dartlab_kernel/sessions',
    this.onOutputEvent,
    this.onStatusEvent,
  }) {
    sessionFilePath = p.absolute(p.join(sessionDir, 'session_$id.dart'));
  }

  bool get isAlive => _process != null && _vmService != null;

  /// Starts the execution runner process and establishes a connection to its VM Service.
  Future<void> start() async {
    // 1. Ensure directory exists
    final dir = Directory(sessionDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 2. Write initial minimal file content
    final initialContent = _synthesizer.synthesizeFileContent([]);
    await File(sessionFilePath).writeAsString(initialContent);

    // 3. Spawn process
    _process = await Process.start('dart', [
      '--enable-vm-service=0',
      sessionFilePath,
    ]);

    final wsUriCompleter = Completer<String>();

    // Helper to extract VM service URL
    void handleLine(String line) {
      final regExp = RegExp(r'The Dart VM service is listening on (https?://[^\s]+)');
      final match = regExp.firstMatch(line);
      if (match != null) {
        final httpUrl = match.group(1)!;
        final uri = Uri.parse(httpUrl);
        final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
        var path = uri.path;
        if (!path.endsWith('/')) {
          path += '/';
        }
        if (!path.endsWith('ws/')) {
          path += 'ws';
        } else {
          path = path.substring(0, path.length - 1);
        }
        final wsUrl = uri.replace(scheme: wsScheme, path: path).toString();
        if (!wsUriCompleter.isCompleted) {
          wsUriCompleter.complete(wsUrl);
        }
      }
    }

    // Listen to stdout and stderr streams of the subprocess
    _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains("The Dart VM service is listening on") ||
          line.contains("The Dart DevTools debugger") ||
          line.contains("RUNNER_READY")) {
        handleLine(line);
        return;
      }
      if (onOutputEvent != null) {
        onOutputEvent!(OutputType.stdout, line);
      }
      if (_isExecuting) {
        _capturedOutputs.add(OutputItem(type: OutputType.stdout, content: line));
      }
    });

    _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains("The Dart VM service is listening on") ||
          line.contains("The Dart DevTools debugger")) {
        handleLine(line);
        return;
      }
      if (onOutputEvent != null) {
        onOutputEvent!(OutputType.stderr, line);
      }
      if (_isExecuting) {
        _capturedOutputs.add(OutputItem(type: OutputType.stderr, content: line));
      }
    });

    // Wait for WebSocket URI (timeout of 10 seconds)
    final wsUrl = await wsUriCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException("Timeout waiting for VM Service port"),
    );

    // Connect to VM Service
    _vmService = await vmServiceConnectUri(wsUrl);

    // Get VM and isolate details
    final vm = await _vmService!.getVM();
    _isolateId = vm.isolates!.first.id!;

    // Get isolate's library ID (with a retry loop to prevent startup race condition)
    final targetUri = Uri.file(sessionFilePath).toString();
    vms.LibraryRef? libRef;
    vms.Isolate? isolate;

    for (int i = 0; i < 50; i++) {
      isolate = await _vmService!.getIsolate(_isolateId!);
      try {
        libRef = isolate.libraries!.firstWhere(
          (lib) => lib.uri == targetUri || lib.uri == sessionFilePath || lib.uri!.endsWith('session_$id.dart'),
        );
        break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (libRef == null) {
      final uris = isolate?.libraries?.map((l) => l.uri).join(', ') ?? '';
      throw StateError("Main library not found in VM isolate. Target URI: $targetUri. Found: $uris");
    }
    _libraryId = libRef.id!;
  }

  /// Executes Dart code inside the session's running process.
  Future<ExecutionResult> execute(String code) async {
    if (!isAlive) {
      throw StateError("Session is not running");
    }

    final startTime = DateTime.now();
    _isExecuting = true;
    _capturedOutputs.clear();

    final errors = <KernelError>[];
    final variables = <VariableInfo>[];

    try {
      // 1. Parse cell and update synthesizer state
      final parsedCell = _synthesizer.parseAndIntegrateCell(code);

      // 2. Synthesize updated file content
      final newContent = _synthesizer.synthesizeFileContent(parsedCell.statements);
      await File(sessionFilePath).writeAsString(newContent);

      // 3. Trigger hot reload
      final reloadReport = await _vmService!.reloadSources(_isolateId!);
      if (!reloadReport.success!) {
        errors.add(KernelError(
          name: "CompileError",
          message: "Failed to compile/reload source code",
        ));
      } else {
        // 4. Evaluate execution method using the wrapper
        final evalResponse = await _vmService!.evaluate(_isolateId!, _libraryId!, '_executeCellWrapper()');

        if (evalResponse is vms.ErrorRef) {
          errors.add(KernelError(
            name: evalResponse.kind ?? "UnhandledException",
            message: evalResponse.message ?? "Exception during evaluation",
          ));
        } else if (evalResponse is vms.Sentinel) {
          errors.add(KernelError(
            name: "SentinelError",
            message: evalResponse.valueAsString ?? "Sentinel encountered during evaluation",
          ));
        } else {
          // Wake up the mutator thread event loop to process microtasks
          try {
            _process!.stdin.write("\n");
            await _process!.stdin.flush();
          } catch (_) {}

          // Poll for completion (timeout after 10 seconds to prevent infinite hangs)
          final startTime = DateTime.now();
          bool isCompleted = false;

          while (DateTime.now().difference(startTime).inSeconds < 10) {
            final completedRef = await _vmService!.evaluate(_isolateId!, _libraryId!, '_cellCompleted');
            if (completedRef is vms.InstanceRef && completedRef.valueAsString == 'true') {
              isCompleted = true;
              break;
            }
            await Future.delayed(const Duration(milliseconds: 10));
          }

          if (!isCompleted) {
            errors.add(KernelError(
              name: "TimeoutException",
              message: "Asynchronous execution timed out after 10 seconds",
            ));
          } else {
            // Check if there was an asynchronous unhandled exception
            final errorRef = await _vmService!.evaluate(_isolateId!, _libraryId!, '_lastError');
            if (errorRef is vms.InstanceRef && errorRef.valueAsString != 'null') {
              final errorMsgRef = await _vmService!.evaluate(_isolateId!, _libraryId!, '_lastError.toString()');
              final stackRef = await _vmService!.evaluate(_isolateId!, _libraryId!, '_lastStackTrace?.toString()');
              errors.add(KernelError(
                name: "UnhandledException",
                message: errorMsgRef is vms.InstanceRef ? (errorMsgRef.valueAsString ?? "Unknown error") : "Exception during evaluation",
                stackTrace: stackRef is vms.InstanceRef && stackRef.valueAsString != 'null'
                    ? stackRef.valueAsString
                    : null,
              ));
            }
          }
        }

        // 5. Inspect active variables
        for (final varName in _synthesizer.declaredVariableNames) {
          try {
            final varResponse = await _vmService!.evaluate(_isolateId!, _libraryId!, varName);
            if (varResponse is vms.InstanceRef) {
              variables.add(VariableInfo(
                name: varName,
                type: varResponse.classRef?.name ?? 'dynamic',
                value: varResponse.valueAsString ?? 'null',
              ));
            }
          } catch (_) {
            // Ignore variables that fail to evaluate
          }
        }
      }
    } on vms.RPCError catch (e) {
      errors.add(KernelError(
        name: "CompileError",
        message: e.message,
      ));
    } catch (e, stack) {
      errors.add(KernelError(
        name: e.runtimeType.toString(),
        message: e.toString(),
        stackTrace: stack.toString(),
      ));
    } finally {
      _isExecuting = false;
    }

    final success = errors.isEmpty;
    final executionTime = DateTime.now().difference(startTime).inMilliseconds;

    return ExecutionResult(
      success: success,
      outputs: List.from(_capturedOutputs),
      errors: errors,
      variables: variables,
      executionTime: executionTime,
    );
  }

  /// Enqueues the code block for sequential execution inside this session.
  Future<ExecutionResult> executeSequential(String code) {
    return _queue.enqueue(() async {
      if (onStatusEvent != null) {
        onStatusEvent!('busy');
      }
      try {
        return await execute(code);
      } finally {
        if (onStatusEvent != null) {
          onStatusEvent!('idle');
        }
      }
    });
  }

  /// Restarts the session by killing the current process and spawning a new one.
  Future<void> restart() async {
    await shutdown();
    await start();
  }

  /// Shuts down the session and cleans up resources.
  Future<void> shutdown() async {
    try {
      _vmService?.dispose();
    } catch (_) {}
    _vmService = null;

    try {
      _process?.kill();
      await _process?.exitCode;
    } catch (_) {}
    _process = null;
    _isolateId = null;
    _libraryId = null;

    try {
      final file = File(sessionFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
