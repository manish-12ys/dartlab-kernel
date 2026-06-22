import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../session/session_manager.dart';
import '../execution/execution_engine.dart';
import '../protocol/protocol.dart';
import '../plugins/plugin_manager.dart';

class KernelManager {
  final SessionManager sessionManager = SessionManager();
  final PluginManager pluginManager = PluginManager();
  late final SessionExecutionEngine executionEngine;
  final Stream<String>? _inputStream;
  final StringSink? _outputSink;

  KernelManager({Stream<String>? inputStream, StringSink? outputSink})
      : _inputStream = inputStream,
        _outputSink = outputSink {
    executionEngine = SessionExecutionEngine(sessionManager);
  }

  /// Starts listening to inputs for JSON-RPC messages and outputting responses.
  void start() {
    final input = _inputStream ??
        stdin.transform(utf8.decoder).transform(const LineSplitter());
    input.listen(_handleInputLine, onDone: shutdown);

    // Watch termination signals for clean process exit
    if (_inputStream == null) {
      _registerSignalHandlers();
    }
  }

  void _registerSignalHandlers() {
    ProcessSignal.sigint.watch().listen((signal) async {
      await shutdown();
      exit(0);
    });

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((signal) async {
        await shutdown();
        exit(0);
      });
    }
  }

  Future<void> _handleInputLine(String line) async {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    String? requestId;
    String? sessionId;

    try {
      final request = Protocol.parseRequest(trimmed);
      requestId = request.id;
      sessionId = request.sessionId ?? 'default';

      switch (request.type) {
        case 'execute':
          final code = request.payload['code'] as String?;
          if (code == null) {
            _sendErrorResponse(requestId, "Missing 'code' parameter in payload");
            return;
          }

          // Lazy-load session if it doesn't exist
          var session = sessionManager.getSession(sessionId);
          if (session == null) {
            session = await sessionManager.createSession(
              sessionId,
              onOutputEvent: (type, content) {
                // Stream real-time output events back to client
                final eventJson = Protocol.serializeEvent(type.name, sessionId!, {'content': content});
                _sendLine(eventJson);
              },
              onStatusEvent: (state) {
                // Stream real-time status events back to client
                final eventJson = Protocol.serializeEvent('status', sessionId!, {'state': state});
                _sendLine(eventJson);
              },
            );
          }

          // Trigger pre-execution hooks on plugins
          await pluginManager.triggerExecuteStart(code);

          final result = await executionEngine.execute(sessionId, code);

          // Trigger post-execution hooks on plugins
          await pluginManager.triggerExecuteEnd(result);

          // Return execution result response
          final responseJson = Protocol.serializeResponse(requestId, result.success, {
            'success': result.success,
            'outputs': result.outputs.map((o) => o.toJson()).toList(),
            'variables': result.variables.map((v) => v.toJson()).toList(),
            'errors': result.errors.map((e) => e.toJson()).toList(),
            'executionTime': result.executionTime,
          });
          _sendLine(responseJson);
          break;

        case 'interrupt':
          final session = sessionManager.getSession(sessionId);
          if (session == null) {
            _sendErrorResponse(requestId, "Session $sessionId not found");
            return;
          }

          // Interrupting restarts the runner process, terminating running code
          // and keeping declarations intact.
          await session.restart();
          _sendLine(Protocol.serializeResponse(requestId, true, {'message': 'Session interrupted'}));
          break;

        case 'restart':
          final session = sessionManager.getSession(sessionId);
          if (session == null) {
            _sendErrorResponse(requestId, "Session $sessionId not found");
            return;
          }
          await session.restart();
          _sendLine(Protocol.serializeResponse(requestId, true, {'message': 'Session restarted'}));
          break;

        case 'shutdown':
          await sessionManager.closeSession(sessionId);
          _sendLine(Protocol.serializeResponse(requestId, true, {'message': 'Session shutdown'}));
          break;

        default:
          _sendErrorResponse(requestId, "Unknown request type: ${request.type}");
      }
    } catch (e) {
      _sendErrorResponse(requestId ?? 'unknown', e.toString());
    }
  }

  void _sendLine(String line) {
    if (_outputSink != null) {
      _outputSink!.writeln(line);
    } else {
      stdout.writeln(line);
    }
  }

  void _sendErrorResponse(String requestId, String message) {
    final responseJson = Protocol.serializeResponse(requestId, false, {
      'errors': [
        {'name': 'ProtocolError', 'message': message}
      ]
    });
    _sendLine(responseJson);
  }

  Future<void> shutdown() async {
    pluginManager.clear();
    await sessionManager.shutdownAll();
  }
}
