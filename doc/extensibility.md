# Extensibility & Packaging Guide - DartLab Kernel

This document provides instructions on how to extend the kernel using plugins, connect it to custom IDEs, and compile it as a reusable package for the Dart/Flutter ecosystem.

---

## 1. Creating Custom Plugins

The kernel includes a `PluginManager` that runs lifecycle hooks before and after executions. You can extend the kernel by creating subclass implementations of `KernelPlugin`.

### Example Plugin

Below is an example of an AI-assisted logging/profiling plugin:

```dart
import 'dart:async';
import 'package:dartlab_kernel/kernel/kernel.dart';

class ExecutionProfilerPlugin extends KernelPlugin {
  late Stopwatch _stopwatch;

  @override
  String get name => "ExecutionProfilerPlugin";

  @override
  FutureOr<void> initialize() {
    print("Profiler plugin initialized!");
  }

  @override
  FutureOr<void> onExecuteStart(String code) {
    _stopwatch = Stopwatch()..start();
    print("Executing code: $code");
  }

  @override
  FutureOr<void> onExecuteEnd(ExecutionResult result) {
    _stopwatch.stop();
    print("Execution completed in ${_stopwatch.elapsedMilliseconds}ms");
    print("Variables modified: ${result.variables.map((v) => v.name).join(', ')}");
  }
}
```

### Registering Plugins
Register your plugin via the `pluginManager` of the `KernelManager`:
```dart
final manager = KernelManager();
await manager.pluginManager.register(ExecutionProfilerPlugin());
manager.start();
```

---

## 2. IDE / Frontend Integration

The kernel communicates using stdio JSON-RPC. To integrate with editors (VS Code, Flutter Desktops):
1. **Spawn**: Launch `dart bin/dartlab_kernel.dart --protocol`.
2. **Listen**: Read `stdout` and transform using `LineSplitter()`.
3. **Write**: Send JSON-RPC strings followed by `\n` and flush the stdin stream.
4. **Lifecycle**: Use requests like `execute` for running code, `inspect` for variables, `interrupt` to cancel runaway processes, and `shutdown` to dispose.

---

## 3. Packaging as a Pub Package

To publish the kernel as a package on [pub.dev](https://pub.dev):
1. **Configure `pubspec.yaml`**:
   - Change `publish_to: none` to `publish_to: https://pub.dev` (or omit it).
   - Set details like `homepage`, `repository`, and `issue_tracker`.
2. **Export APIs**:
   - All public components should remain exported in [lib/kernel/kernel.dart](file:///home/mh/Projects/dnb/dartlab-kernel/lib/kernel/kernel.dart).
3. **Executable binary**:
   - The file `bin/dartlab_kernel.dart` will be compiled as a global command-line tool when users activate the package globally via `dart pub global activate dartlab_kernel`.
