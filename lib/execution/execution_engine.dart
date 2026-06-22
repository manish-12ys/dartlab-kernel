import '../models/execution_result.dart';
import '../session/session_manager.dart';

abstract class ExecutionEngine {
  Future<ExecutionResult> execute(String sessionId, String code);
}

class SessionExecutionEngine implements ExecutionEngine {
  final SessionManager sessionManager;

  SessionExecutionEngine(this.sessionManager);

  @override
  Future<ExecutionResult> execute(String sessionId, String code) async {
    final session = sessionManager.getSession(sessionId);
    if (session == null) {
      throw ArgumentError("Session with ID $sessionId not found");
    }
    return await session.executeSequential(code);
  }
}
