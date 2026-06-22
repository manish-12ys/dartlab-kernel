import 'variable_info.dart';

enum OutputType { stdout, stderr }

class OutputItem {
  final OutputType type;
  final String content;

  OutputItem({
    required this.type,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'content': content,
      };

  factory OutputItem.fromJson(Map<String, dynamic> json) => OutputItem(
        type: OutputType.values.byName(json['type'] as String),
        content: json['content'] as String,
      );
}

class KernelError {
  final String name;
  final String message;
  final String? stackTrace;

  KernelError({
    required this.name,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };

  factory KernelError.fromJson(Map<String, dynamic> json) => KernelError(
        name: json['name'] as String,
        message: json['message'] as String,
        stackTrace: json['stackTrace'] as String?,
      );
}

class ExecutionResult {
  final bool success;
  final List<OutputItem> outputs;
  final List<KernelError> errors;
  final List<VariableInfo> variables;
  final int executionTime;

  ExecutionResult({
    required this.success,
    required this.outputs,
    required this.errors,
    required this.variables,
    required this.executionTime,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'outputs': outputs.map((e) => e.toJson()).toList(),
        'errors': errors.map((e) => e.toJson()).toList(),
        'variables': variables.map((e) => e.toJson()).toList(),
        'executionTime': executionTime,
      };

  factory ExecutionResult.fromJson(Map<String, dynamic> json) => ExecutionResult(
        success: json['success'] as bool,
        outputs: (json['outputs'] as List)
            .map((e) => OutputItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        errors: (json['errors'] as List)
            .map((e) => KernelError.fromJson(e as Map<String, dynamic>))
            .toList(),
        variables: (json['variables'] as List)
            .map((e) => VariableInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        executionTime: json['executionTime'] as int,
      );
}
