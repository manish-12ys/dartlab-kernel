import 'dart:async';

class ExecutionQueue {
  Future<void> _lastTask = Future.value();

  /// Enqueues a job and returns its result when it is executed.
  /// Guarantees that jobs are executed sequentially in FIFO order.
  Future<T> enqueue<T>(Future<T> Function() job) {
    final completer = Completer<T>();

    // Chain the new task to the end of the queue
    _lastTask = _lastTask.then((_) async {
      try {
        final result = await job();
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });

    return completer.future;
  }
}
