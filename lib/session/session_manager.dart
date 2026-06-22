import 'dart:async';
import '../models/execution_result.dart';
import 'notebook_session.dart';

class SessionManager {
  final Map<String, NotebookSession> _sessions = {};
  final Map<String, Future<NotebookSession>> _pendingSessions = {};
  final String sessionDir;

  SessionManager({this.sessionDir = '.dartlab_kernel/sessions'});

  /// Creates and starts a new notebook session.
  Future<NotebookSession> createSession(
    String id, {
    void Function(OutputType type, String line)? onOutputEvent,
    void Function(String state)? onStatusEvent,
  }) async {
    if (_sessions.containsKey(id)) {
      throw ArgumentError("Session with ID $id already exists");
    }

    if (_pendingSessions.containsKey(id)) {
      return _pendingSessions[id]!;
    }

    final completer = Completer<NotebookSession>();
    _pendingSessions[id] = completer.future;

    try {
      final session = NotebookSession(
        id: id,
        sessionDir: sessionDir,
        onOutputEvent: onOutputEvent,
        onStatusEvent: onStatusEvent,
      );
      await session.start();
      _sessions[id] = session;
      completer.complete(session);
      return session;
    } catch (e, s) {
      completer.completeError(e, s);
      rethrow;
    } finally {
      _pendingSessions.remove(id);
    }
  }

  /// Closes and cleans up a notebook session.
  Future<void> closeSession(String id) async {
    _pendingSessions.remove(id);
    final session = _sessions.remove(id);
    if (session != null) {
      await session.shutdown();
    }
  }

  /// Retrieves an existing notebook session.
  NotebookSession? getSession(String id) {
    return _sessions[id];
  }

  /// Shuts down all active sessions.
  Future<void> shutdownAll() async {
    _pendingSessions.clear();
    final ids = List<String>.from(_sessions.keys);
    for (final id in ids) {
      await closeSession(id);
    }
  }
}
