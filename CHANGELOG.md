# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-phase1] - 2026-06-23

### Added
- Initial project layout and structure.
- `pubspec.yaml` with packages `analyzer`, `vm_service`, `path`, and `test`.
- **Domain Models**: Introduced `ExecutionResult`, `OutputItem`, `KernelError`, `VariableInfo`, and `KernelMessage` representing kernel protocol inputs/outputs.
- **Session Management**: Built `NotebookSession` and `SessionManager` managing child Dart JIT subprocesses running on custom, dynamically resolved VM Service ports (`--enable-vm-service=0`).
- **Parsing & AST Synthesis**: Created `SourceSynthesizer` using `package:analyzer` to parse cells, separate declarations from execution statements, filter out recovery AST dummy nodes containing syntax errors, and maintain cumulative definitions in the session file.
- **Asynchronous Execution & Exception Capture**: Designed an async cell runner wrapper in `SourceSynthesizer` and `NotebookSession` with a polling loop and `stdin` event loop wake-up stream write, enabling robust handling and stack trace capture of both synchronous and asynchronous errors.
- **Console Application Harness**: Implemented `bin/dartlab_kernel.dart` which provides a fully functional interactive CLI REPL.
- **Test Suite**: Created 9 unit and integration tests covering parser synthesis, multi-cell stateful persistence, standard stream capturing, syntax compilation errors, and unhandled exception propagation.

## [0.2.0-phase2] - 2026-06-23

### Added
- **Protocol Layer**: Implemented `Protocol` utility for JSON-RPC 2.0 serialization/deserialization of requests, responses, and real-time events.
- **Execution Queue**: Created `ExecutionQueue` to guarantee sequential, ordered cell execution in a FIFO manner per session.
- **Interrupt & State Recovery**: Implemented stateful subprocess re-spawning under `NotebookSession.restart()` which terminates runaway execution loops (e.g. `while (true) {}`) while retaining the session's cumulative declarations in the synthesizer.
- **Event-Driven State Engine**: Integrated status events (`busy`, `idle`) to indicate runner isolate activity status cleanly without concurrent event overlap.
- **Demo Client**: Created `example/demo_client.dart` showing protocol exchange over stdio with the kernel.
- **Protocol & Interrupt Tests**: Added integration tests in `test/protocol_test.dart` for the JSON-RPC interface, sequential cell execution, session restart/shutdown, and stateful interrupt recovery.

## [0.3.0] - 2026-06-23

### Added
- **Plugin System / Framework**: Created `KernelPlugin` abstract base class and `PluginManager` class supporting `initialize`, `onExecuteStart`, and `onExecuteEnd` execution hooks.
- **Zombie Process Cleanup**: Registered `sigint` and `sigterm` signal handlers inside `KernelManager` to cleanly shut down and kill all active child JIT processes and delete temporary files on abrupt program exit.
- **Documentation**: Generated standard `README.md` at the repository root, alongside architecture specification (`doc/architecture.md`), Mermaid-based sequence diagrams (`doc/sequence_diagrams.md`), and extensibility/packaging guidelines (`doc/extensibility.md`).
- **Tests**: Created a new test suite in `test/plugin_test.dart` to verify registration, initialization, execution hook invocation, and error isolation of the plugin framework.
- **Package Release Preparation**: Renamed directory layout from plural `docs` and `examples` to singular `doc` and `example` to align with pub.dev layout standards.
- **Static Warning Cleanup**: Resolved unused imports in `kernel_manager.dart` and dead null-aware expression in `notebook_session.dart`.
- **CI/CD Pipelines**: Configured GitHub Actions CI pipeline (`dart.yml`) with automated `dart pub publish --dry-run` checks, and CD pipeline (`publish.yml`) for automated secure OIDC-based publishing to pub.dev upon tag pushes.
