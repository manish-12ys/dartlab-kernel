class KernelMessage {
  final String id;
  final String type;
  final String? sessionId;
  final Map<String, dynamic> payload;

  KernelMessage({
    required this.id,
    required this.type,
    this.sessionId,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (sessionId != null) 'sessionId': sessionId,
        'payload': payload,
      };

  factory KernelMessage.fromJson(Map<String, dynamic> json) {
    return KernelMessage(
      id: json['id'] as String,
      type: json['type'] as String,
      sessionId: json['sessionId'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}
