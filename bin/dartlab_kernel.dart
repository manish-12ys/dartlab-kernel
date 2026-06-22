import 'dart:io';
import 'package:dartlab_kernel/session/session_manager.dart';
import 'package:dartlab_kernel/execution/execution_engine.dart';
import 'package:dartlab_kernel/models/execution_result.dart';

import 'package:dartlab_kernel/kernel/kernel_manager.dart';

void main(List<String> arguments) async {
  if (arguments.contains('--protocol')) {
    final manager = KernelManager();
    manager.start();
    return;
  }

  print("==============================================");
  print("     DARTLAB KERNEL - INTERACTIVE SHELL       ");
  print("==============================================");
  print("Write Dart code and press Enter on an empty line to execute.");
  print("Type 'exit' to quit, 'restart' to restart the session.");
  print("==============================================");

  final sessionManager = SessionManager();
  final engine = SessionExecutionEngine(sessionManager);
  
  const sessionId = "cli-session";
  
  try {
    print("Starting Dart execution session...");
    await sessionManager.createSession(sessionId);
    print("Session ready. Start coding!\n");
  } catch (e) {
    print("Error starting session: $e");
    exit(1);
  }

  final buffer = StringBuffer();

  while (true) {
    if (buffer.isEmpty) {
      stdout.write("dartlab> ");
    } else {
      stdout.write("    ... ");
    }

    final line = stdin.readLineSync();
    if (line == null) break;

    final trimmed = line.trim();
    if (trimmed == 'exit') {
      break;
    } else if (trimmed == 'restart') {
      print("Restarting execution session...");
      buffer.clear();
      final session = sessionManager.getSession(sessionId);
      if (session != null) {
        await session.restart();
      }
      print("Session restarted.\n");
      continue;
    }

    if (line.isEmpty) {
      if (buffer.isEmpty) {
        continue;
      }
      
      // Execute the accumulated buffer
      final codeToExecute = buffer.toString();
      buffer.clear();
      
      print("\n[Executing...]");
      try {
        final result = await engine.execute(sessionId, codeToExecute);
        
        // Print execution status
        if (result.success) {
          print("Status: SUCCESS (took ${result.executionTime}ms)");
        } else {
          print("Status: FAILED (took ${result.executionTime}ms)");
        }

        // Print stdout/stderr outputs
        if (result.outputs.isNotEmpty) {
          print("\n--- Outputs ---");
          for (final output in result.outputs) {
            if (output.type == OutputType.stdout) {
              print("[stdout] ${output.content}");
            } else {
              print("[stderr] ${output.content}");
            }
          }
        }

        // Print errors
        if (result.errors.isNotEmpty) {
          print("\n--- Errors ---");
          for (final err in result.errors) {
            print("[${err.name}]: ${err.message}");
            if (err.stackTrace != null) {
              print(err.stackTrace);
            }
          }
        }

        // Print variables
        if (result.variables.isNotEmpty) {
          print("\n--- Variables ---");
          for (final variable in result.variables) {
            print("  ${variable.name} (${variable.type}) = ${variable.value}");
          }
        }
        print("");
      } catch (e) {
        print("Execution Engine Error: $e\n");
      }
    } else {
      buffer.writeln(line);
    }
  }

  print("Shutting down session...");
  await sessionManager.shutdownAll();
  print("Goodbye!");
}
