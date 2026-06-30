import 'dart:async';
import 'dart:io';

dynamic _lastResult;
dynamic _lastError;
dynamic _lastStackTrace;
bool _cellCompleted = false;

dynamic _executeCellWrapper() {
  _lastResult = null;
  _lastError = null;
  _lastStackTrace = null;
  _cellCompleted = false;
  try {
    final res = _executeCell();
    if (res is Future) {
      res.then((val) {
        _lastResult = val;
        _cellCompleted = true;
      }).catchError((err, stack) {
        _lastError = err;
        _lastStackTrace = stack;
        _cellCompleted = true;
      });
      return res;
    } else {
      _lastResult = res;
      _cellCompleted = true;
      return res;
    }
  } catch (e, s) {
    _lastError = e;
    _lastStackTrace = s;
    _cellCompleted = true;
    rethrow;
  }
}

void main() async {
  print("RUNNER_READY");
  final completer = Completer<void>();
  stdin.listen(
    (data) {},
    onDone: () => completer.complete(),
  );
  await completer.future;
}

dynamic _executeCell() async {
void main() {
  print("missing closing paren"
}
}