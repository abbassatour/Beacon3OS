import 'dart:convert';
import 'dart:developer';

/// أنواع الرسائل المتبادلة محلياً بين أجهزة BeaconOS
enum P2pMessageType {
  ping,
  pong,
  handshake,
  locateDevice,
  triggerSos,
  vaultMutation,
  telemetry,
  devicePairing,
  unknown,
}

/// كبسولة الرسائل المحلية الموحدة (Self-Contained P2P Message Envelope)
class P2pMessage {
  const P2pMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.senderId,
    this.senderType,
  });

  /// المعرف الفريد للرسالة لمنع التكرار (Deduplication)
  final String id;
  final P2pMessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final String? senderId;
  final String? senderType;

  factory P2pMessage.create({
    required P2pMessageType type,
    required Map<String, dynamic> payload,
    String? senderId,
    String? senderType,
    String? customId,
  }) {
    return P2pMessage(
      id: customId ?? '${DateTime.now().microsecondsSinceEpoch}_${type.name}',
      type: type,
      payload: payload,
      timestamp: DateTime.now(),
      senderId: senderId,
      senderType: senderType,
    );
  }

  factory P2pMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'unknown';
    final p2pType = P2pMessageType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      orElse: () => P2pMessageType.unknown,
    );

    return P2pMessage(
      id: json['id'] as String? ?? '${DateTime.now().millisecondsSinceEpoch}',
      type: p2pType,
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      senderId: json['sender_id'] as String?,
      senderType: json['sender_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      if (senderId != null) 'sender_id': senderId,
      if (senderType != null) 'sender_type': senderType,
    };
  }

  String encode() => jsonEncode(toJson());

  static P2pMessage? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return P2pMessage.fromJson(decoded);
      }
    } catch (e) {
      log('LocalP2pClient: Failed to decode message: $e');
    }
    return null;
  }
}