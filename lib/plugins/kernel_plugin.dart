import 'dart:async';
import '../models/execution_result.dart';

abstract class KernelPlugin {
  /// The unique name identifying this plugin.
  String get name;

  /// Initializes the plugin. Called once during plugin registration.
  FutureOr<void> initialize();

  /// Called immediately before a code block is executed.
  FutureOr<void> onExecuteStart(String code);

  /// Called immediately after a code block has finished executing.
  FutureOr<void> onExecuteEnd(ExecutionResult result);
}
