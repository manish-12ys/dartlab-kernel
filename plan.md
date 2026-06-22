# DARTLAB KERNEL — MASTER IMPLEMENTATION PROMPT

Create a production-grade repository called **dartlab-kernel**.

The repository will be the execution engine for the DartLab ecosystem.

The kernel should serve the same role that the IPython Kernel serves in Jupyter.

The kernel must be completely local-first.

No authentication.

No cloud services.

No backend server dependency.

No databases.

Everything runs on the user's machine.

---

# Vision

Build a reusable Dart execution kernel that allows notebook applications, IDEs, CLI tools, and future editors to execute Dart code interactively while maintaining runtime state across notebook cells.

The kernel must support:

* Notebook execution
* Interactive execution
* Persistent runtime state
* Variable inspection
* Output capture
* Error handling
* Interrupting execution
* Restarting execution
* Future debugging support

The kernel should be reusable by:

* Flutter Desktop
* VS Code Extension
* CLI
* Future JetBrains Plugin
* Future Web Runtime

---

# Repository Name

```text
dartlab-kernel
```

---

# High-Level Architecture

Design the system using:

```text
Kernel Core
│
├── Session Manager
├── Execution Engine
├── Runtime State Manager
├── Variable Inspector
├── Output Capture
├── Error Manager
├── Lifecycle Manager
├── Protocol Layer
└── Plugin System
```

Generate complete architecture documentation.

---

# Primary Goal

Support notebook execution like:

Cell 1

```dart
var x = 10;
```

Cell 2

```dart
print(x);
```

Output

```text
10
```

State must persist between cells.

---

# Repository Structure

Generate complete repository structure.

```text
dartlab-kernel/
│
├── lib/
│   │
│   ├── kernel/
│   │   ├── kernel.dart
│   │   ├── kernel_manager.dart
│   │   └── kernel_state.dart
│   │
│   ├── session/
│   │   ├── session_manager.dart
│   │   ├── notebook_session.dart
│   │   └── session_registry.dart
│   │
│   ├── execution/
│   │   ├── execution_engine.dart
│   │   ├── code_executor.dart
│   │   ├── execution_queue.dart
│   │   └── execution_context.dart
│   │
│   ├── runtime/
│   │   ├── state_manager.dart
│   │   ├── variable_store.dart
│   │   ├── import_store.dart
│   │   └── symbol_table.dart
│   │
│   ├── inspection/
│   │   ├── variable_inspector.dart
│   │   ├── memory_inspector.dart
│   │   └── type_inspector.dart
│   │
│   ├── outputs/
│   │   ├── stdout_capture.dart
│   │   ├── stderr_capture.dart
│   │   ├── output_manager.dart
│   │   └── output_types.dart
│   │
│   ├── errors/
│   │   ├── error_manager.dart
│   │   ├── exception_mapper.dart
│   │   └── diagnostics.dart
│   │
│   ├── lifecycle/
│   │   ├── startup.dart
│   │   ├── restart.dart
│   │   ├── interrupt.dart
│   │   └── shutdown.dart
│   │
│   ├── protocol/
│   │   ├── protocol.dart
│   │   ├── requests.dart
│   │   ├── responses.dart
│   │   └── events.dart
│   │
│   ├── plugins/
│   │   ├── plugin_manager.dart
│   │   └── kernel_plugin.dart
│   │
│   └── models/
│       ├── execution_result.dart
│       ├── kernel_message.dart
│       └── variable_info.dart
│
├── bin/
│   └── dartlab_kernel.dart
│
├── test/
│
├── example/
│
├── doc/
│
└── README.md
```

Generate every file.

---

# Session Manager

The kernel must support multiple notebook sessions.

Example:

```text
Notebook A
Notebook B
Notebook C
```

Each notebook must have:

```text
Independent Runtime
Independent Variables
Independent Imports
Independent Outputs
```

Design:

```dart
abstract class SessionManager {
  Future<NotebookSession> createSession();
  Future<void> closeSession(String id);
  NotebookSession? getSession(String id);
}
```

Generate full implementation.

---

# Execution Engine

The execution engine is responsible for executing Dart code.

Capabilities:

* Execute code
* Compile code
* Evaluate expressions
* Handle async code
* Return outputs

Generate:

```dart
abstract class ExecutionEngine {
  Future<ExecutionResult> execute(
    String sessionId,
    String code,
  );
}
```

Design complete implementation.

---

# Runtime State Management

The runtime must preserve:

```dart
Variables
Classes
Functions
Imports
Extensions
Enums
Records
Typedefs
```

Example:

Cell 1

```dart
class User {
  String name;
  User(this.name);
}
```

Cell 2

```dart
var user = User("John");
print(user.name);
```

Must work correctly.

Generate architecture for preserving state.

---

# Variable Inspector

Build a runtime variable explorer.

The inspector should return:

```json
[
  {
    "name": "x",
    "type": "int",
    "value": "10"
  }
]
```

Support:

* Primitive types
* Collections
* Objects
* Records

Generate inspection APIs.

---

# Output Capture System

Capture:

```text
stdout
stderr
```

Example:

```dart
print("Hello");
```

Output:

```json
{
  "type": "stdout",
  "content": "Hello"
}
```

Generate full architecture.

---

# Exception Handling

Capture:

```dart
throw Exception("Failed");
```

Return:

```json
{
  "type": "error",
  "name": "Exception",
  "message": "Failed",
  "stackTrace": "..."
}
```

Generate:

* Error model
* Diagnostics
* Error categorization

---

# Execution Result Model

Design:

```dart
class ExecutionResult {
  final bool success;
  final List<OutputItem> outputs;
  final List<KernelError> errors;
  final List<VariableInfo> variables;
  final int executionTime;
}
```

Generate complete implementation.

---

# Kernel Lifecycle

Support:

```text
START
RESTART
INTERRUPT
SHUTDOWN
```

Design:

```dart
kernel.start();
kernel.restart();
kernel.interrupt();
kernel.shutdown();
```

Document lifecycle transitions.

---

# Execution Queue

The kernel must execute cells sequentially.

Example:

```text
Cell 1
Cell 2
Cell 3
```

No race conditions.

Generate:

* Queue architecture
* Scheduling system
* Cancellation strategy

---

# Protocol Layer

The kernel must communicate with external clients.

Future clients:

```text
Flutter Desktop
VS Code
CLI
```

Design a JSON-RPC inspired protocol.

Request:

```json
{
  "id": "1",
  "type": "execute",
  "sessionId": "abc",
  "code": "print('Hello')"
}
```

Response:

```json
{
  "id": "1",
  "success": true
}
```

Generate:

* Message schema
* Events
* Requests
* Responses

---

# Memory Management

Design:

* Runtime cleanup
* Object disposal
* Session cleanup
* Resource monitoring

Prevent:

```text
Memory leaks
Zombie sessions
Runaway execution
```

Generate architecture.

---

# Plugin System

Allow future extensions.

Examples:

```text
AI Plugin
Debugger Plugin
Profiler Plugin
Chart Plugin
```

Design:

```dart
abstract class KernelPlugin {
  String get name;
  Future<void> initialize();
}
```

Generate plugin framework.

---

# Testing Strategy

Create tests for:

```text
Variable persistence
Class persistence
Import persistence
Output capture
Error capture
Restart
Interrupt
Shutdown
Multi-session execution
Protocol messages
```

Generate complete test architecture.

---

# Performance Goals

Target:

```text
Kernel Startup < 1 sec
Cell Execution < 100 ms overhead
Memory Efficient
Cross Platform
```

Support:

```text
Windows
Linux
macOS
```

---

# Deliverables

Generate:

1. Complete architecture
2. All domain models
3. Session manager
4. Execution engine
5. Runtime state manager
6. Variable inspector
7. Output capture system
8. Error manager
9. Lifecycle manager
10. Protocol layer
11. Plugin framework
12. Test architecture
13. Documentation
14. Sequence diagrams
15. Future extensibility strategy

The final result should be production-grade, open-source friendly, highly modular, and capable of becoming the official Dart notebook kernel for the DartLab ecosystem.
