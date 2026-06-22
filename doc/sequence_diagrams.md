# Sequence Diagrams - DartLab Kernel

This document provides visual flow sequences for major kernel operations.

---

## 1. Cell Execution Sequence

This diagram details the sequence when a client sends an `execute` request over the JSON-RPC interface.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant KM as KernelManager
    participant SM as SessionManager
    participant NS as NotebookSession
    participant SS as SourceSynthesizer
    participant VM as Dart Runner VM

    Client->>KM: JSON-RPC "execute" (code)
    activate KM
    KM->>SM: getOrCreateSession(sessionId)
    activate SM
    SM-->>KM: NotebookSession
    deactivate SM
    KM->>NS: executeSequential(code)
    activate NS
    NS->>NS: enqueue()
    NS->>SS: parseAndIntegrateCell(code)
    activate SS
    SS-->>NS: ParsedCell (imports, declarations, statements)
    deactivate SS
    NS->>NS: synthesizeFileContent() & write to disk
    NS->>VM: VM Service: reloadSources()
    activate VM
    VM-->>NS: ReloadReport (Success)
    deactivate VM
    NS->>VM: VM Service: evaluate("_executeCellWrapper()")
    activate VM
    VM-->>NS: FutureRef
    deactivate VM
    NS->>VM: Write "\n" to stdin (Wake up event loop)
    NS->>NS: Poll "_cellCompleted" (eval loop)
    NS->>VM: VM Service: evaluate("_cellCompleted")
    activate VM
    VM-->>NS: true
    deactivate VM
    NS->>VM: VM Service: evaluate(variableNames)
    activate VM
    VM-->>NS: Variable Values
    deactivate VM
    NS-->>KM: ExecutionResult (success, variables, outputs)
    deactivate NS
    KM-->>Client: JSON-RPC Response (results)
    deactivate KM
```

---

## 2. Stateful Subprocess Interrupt Sequence

This diagram shows how a runaway execution (e.g. `while(true) {}`) is cancelled while maintaining declarations.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant KM as KernelManager
    participant NS as NotebookSession
    participant VM as Runaway Dart VM
    participant NewVM as Fresh Dart VM

    Note over KM,VM: Cell execution is running an infinite loop: while(true) {}
    Client->>KM: JSON-RPC "interrupt"
    activate KM
    KM->>NS: restart()
    activate NS
    NS->>NS: shutdown()
    NS->>VM: Kill process
    destroy VM
    NS->>NS: start()
    NS->>NS: synthesizeFileContent([]) (Contains cumulative declarations)
    NS->>NewVM: Spawn process (dart --enable-vm-service=0)
    activate NewVM
    NewVM-->>NS: Port / WS URL
    NS->>NS: Connect VM Service
    deactivate NS
    KM-->>Client: JSON-RPC Response (Session interrupted)
    deactivate KM
    Note over Client,NewVM: Subsequent execute requests run against NewVM with all prior classes and variables declared.
```
