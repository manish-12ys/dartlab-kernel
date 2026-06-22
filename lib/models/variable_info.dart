class VariableInfo {
  final String name;
  final String type;
  final String value;

  VariableInfo({
    required this.name,
    required this.type,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'value': value,
      };

  factory VariableInfo.fromJson(Map<String, dynamic> json) => VariableInfo(
        name: json['name'] as String,
        type: json['type'] as String,
        value: json['value'] as String,
      );
}
