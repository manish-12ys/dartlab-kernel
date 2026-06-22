import 'dart:async';
import '../models/execution_result.dart';
import 'kernel_plugin.dart';

class PluginManager {
  final List<KernelPlugin> _plugins = [];

  List<KernelPlugin> get plugins => List.unmodifiable(_plugins);

  /// Registers and initializes a plugin.
  Future<void> register(KernelPlugin plugin) async {
    await plugin.initialize();
    _plugins.add(plugin);
  }

  /// Dispatches the pre-execute hook to all registered plugins.
  Future<void> triggerExecuteStart(String code) async {
    for (final plugin in _plugins) {
      try {
        await plugin.onExecuteStart(code);
      } catch (_) {
        // Suppress plugin hook errors to avoid crashing the main execution pipeline
      }
    }
  }

  /// Dispatches the post-execute hook to all registered plugins.
  Future<void> triggerExecuteEnd(ExecutionResult result) async {
    for (final plugin in _plugins) {
      try {
        await plugin.onExecuteEnd(result);
      } catch (_) {
        // Suppress plugin hook errors to avoid crashing the main execution pipeline
      }
    }
  }

  /// Cleans up and unregisters all plugins.
  void clear() {
    _plugins.clear();
  }
}
