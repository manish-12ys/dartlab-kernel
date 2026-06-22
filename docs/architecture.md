# Architecture Documentation - DartLab Kernel

This document provides a detailed overview of the core architectural decisions behind the `dartlab-kernel`.

---

## 1. Component Overview

The kernel follows a modular architecture separating session management, compilation, I/O streams, and protocols:

```text
  ┌────────────────────────────────────────────────────────┐
  │                   IDE / Client UI                      │
  └──────────────────────────┬─────────────────────────────┘
                             │ JSON-RPC (stdio)
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │                    Kernel Manager                      │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │                    Session Manager                     │
  └───────────┬──────────────────────────────────┬─────────┘
              │                                  │
              ▼                                  ▼
      ┌───────────────┐                  ┌───────────────┐
      │   Session A   │                  │   Session B   │
      └───────┬───────┘                  └───────┬───────┘
              │                                  │
              ▼                                  ▼
      ┌───────────────┐                  ┌───────────────┐
      │  Isolate VM   │                  │  Isolate VM   │
      └───────────────┘                  └───────────────┘
```

- **`KernelManager`**: Handles protocol parsing and serialization. Routes commands to the appropriate session. Monitors signal terminations to clean up child processes.
- **`SessionManager`**: Holds the session registry. Guarantees that session startup requests are de-duplicated using a cache of futures, avoiding port collisions.
- **`NotebookSession`**: Spawns the JIT subprocess, negotiates WebSocket connection with the VM Service, captures stdout/stderr, and executes cell wrappers.
- **`SourceSynthesizer`**: Deconstructs cells using `package:analyzer` to split imports and top-level declarations (functions, classes, variables) from expressions/statements. It keeps class and function declarations cumulative.
- **`ExecutionQueue`**: Chains execution futures in a FIFO order per session to avoid execution race conditions.

---

## 2. Key Design Decisions

### JIT Subprocess Execution Strategy
To avoid namespace pollution and crashes propagating to the parent kernel manager, each session runs in its own spawned Dart VM subprocess. The subprocess starts with a minimal template file that imports standard packages and listens to `stdin` to keep the process alive.

### VM Service and Hot Reload
Compilation of subsequent cells is performed using Hot Reload. 
1. The `SourceSynthesizer` parses the new cell, updates the cumulative AST state, and writes the synthesized code to the session's file.
2. The VM Service connection triggers `reloadSources`.
3. The kernel invokes `evaluate` on a wrapper method `_executeCellWrapper()` to execute the cell statement payload.

### The Stdin Mutator Wake-up
Because the runner process isolates suspend when waiting on input from `stdin` (a blocking select/poll call), microtasks queued in the isolate (e.g. `Future.then` callbacks) would not execute until the event loop wakes up.
To solve this, immediately after calling `evaluate`, the `NotebookSession` writes a newline `\n` to the subprocess's `stdin` and flushes it. This immediately triggers the event loop to wake up and process all pending microtasks, preventing execution hangs on async operations.

### Stateful Re-spawning Interrupts
Dart isolates cannot be asynchronously interrupted without tearing down the isolate. To interrupt a runaway cell (e.g. `while(true) {}`), the kernel:
1. Kills the active subprocess.
2. Creates a new subprocess.
3. Reloads the synthesized source file (which has all variables, classes, and functions declared up to that point).
4. Recovers state by compiling and executing the code up to that point.
