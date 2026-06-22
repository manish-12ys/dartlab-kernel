import 'dart:convert';
import '../models/kernel_message.dart';

class Protocol {
  /// Parses a raw incoming JSON string into a [KernelMessage] request.
  static KernelMessage parseRequest(String rawJson) {
    final Map<String, dynamic> data = jsonDecode(rawJson) as Map<String, dynamic>;
    return KernelMessage.fromJson(data);
  }

  /// Serializes a response to an incoming request.
  static String serializeResponse(String id, bool success, Map<String, dynamic> payload) {
    return jsonEncode({
      'id': id,
      'success': success,
      'payload': payload,
    });
  }

  /// Serializes a real-time event to stream to connected clients.
  static String serializeEvent(String eventName, String sessionId, Map<String, dynamic> payload) {
    return jsonEncode({
      'type': 'event',
      'event': eventName,
      'sessionId': sessionId,
      'payload': payload,
    });
  }
}
