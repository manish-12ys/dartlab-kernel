# DartLab Kernel

A production-grade, local-first Dart execution kernel. The DartLab Kernel is designed to serve the same role in the DartLab ecosystem that the IPython Kernel serves in Jupyter, enabling interactive, cell-by-cell execution of Dart code while maintaining stateful variables, classes, imports, and functions across evaluations.

## Features

- **Stateful JIT Compilation**: Keeps classes, functions, enums, extensions, typedefs, variables, and imports alive and cumulative across cell executions.
- **Process Isolation**: Spawns independent sessions inside separate Dart VM processes with dynamically assigned WebSocket VM Service ports (`--enable-vm-service=0`), ensuring process isolation.
- **Sequential Task Queueing**: Uses a FIFO scheduling queue to prevent concurrent cell executions from overlapping or racing.
- **Interrupts & Stateful Re-spawning**: Cleanly interrupts long-running or infinite loops (e.g. `while(true) {}`) by terminating the runner isolate and re-spawning a new process while restoring all previously compiled declarations.
- **JSON-RPC Protocol Layer**: Communcates over standard input/output with external frontends (e.g., Flutter Desktop, VS Code, CLI runners).
- **Extensible Plugin Framework**: Easily hook into pre-execution and post-execution lifecycles via the plugin system.

---

## Directory Structure

```text
dartlab-kernel/
├── bin/
│   └── dartlab_kernel.dart      # CLI interactive shell harness
├── lib/
│   ├── execution/
│   │   ├── execution_engine.dart # High-level JIT execution orchestrator
│   │   ├── execution_queue.dart  # FIFO sequential execution scheduler
│   │   └── source_synthesizer.dart # AST parser, declaration/statement separator
│   ├── kernel/
│   │   ├── kernel.dart           # Library entrypoint
│   │   └── kernel_manager.dart   # JSON-RPC protocol router and signal handler
│   ├── models/
│   │   ├── execution_result.dart # Models for outputs, errors, variables
│   │   ├── kernel_message.dart   # JSON-RPC request representation
│   │   └── variable_info.dart    # Holds evaluated variable state
│   ├── plugins/
│   │   ├── kernel_plugin.dart    # Base plugin abstract class
│   │   └── plugin_manager.dart   # Registering and dispatching plugin hooks
│   ├── protocol/
│   │   └── protocol.dart         # Parser/serializer for JSON-RPC messages
│   └── session/
│       ├── notebook_session.dart # Spawns VM, hot reloads, inspects variables
│       └── session_manager.dart  # Deduplicated session lifecycle manager
├── examples/
│   └── demo_client.dart          # Stdio JSON-RPC demo harness client
└── test/
    ├── execution_engine_test.dart
    ├── plugin_test.dart
    ├── protocol_test.dart
    └── source_synthesizer_test.dart
```

---

## Getting Started

### Prerequisites

Make sure you have [Dart SDK](https://dart.dev/get-dart) installed (version `>=3.0.0 <4.0.0`).

### Install Dependencies

Run the following command to download dependencies:

```bash
dart pub get
```

---

## Usage

### 1. Interactive CLI REPL Mode

You can run the interactive shell directly from your terminal:

```bash
dart run bin/dartlab_kernel.dart
```

Write Dart code, press **Enter** to write a new line, and press **Enter on an empty line** to execute the cell.
Type `restart` to re-initialize the session, or `exit` to quit.

Example flow:
```text
dartlab> var a = 100;
    ... 

[Executing...]
Status: SUCCESS (took 200ms)

--- Variables ---
  a (int) = 100

dartlab> a += 50;
    ... 

[Executing...]
Status: SUCCESS (took 50ms)

--- Variables ---
  a (int) = 150
```

### 2. Protocol Mode (JSON-RPC stdio)

To start the kernel in protocol mode, launch with the `--protocol` flag:

```bash
dart run bin/dartlab_kernel.dart --protocol
```

This starts the kernel listening on standard input for JSON-RPC requests and outputting serialized responses/events to standard output.

#### Running the Demo Client
To see the protocol in action, run the demo client:
```bash
dart run examples/demo_client.dart
```

---

## Testing

Run the full integration and unit test suite:

```bash
dart test
```
